# Copyright (c) [2017] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "y2storage"
require "y2issues"
require "y2security/security_policies/manager"
require "y2security/security_policies/target_config"
require "autoinstall/activate_callbacks"
require "autoinstall/xml_checks"

Yast.import "Console"
Yast.import "Installation"
Yast.import "Profile"
Yast.import "Timezone"
Yast.import "Keyboard"
Yast.import "Language"

module Y2Autoinstallation
  # This module defines some methods that are used in {Y2Autoinstallation::Clients::InstAutosetup}
  # and {Y2Autoinstallation::Clients::InstAutosetupUpgrade} clients. These clients need to be
  # rewritten but, for the time being, this is the easiest way to share code between them.
  module AutosetupHelpers
    # name of the registration section in the profile
    REGISTER_SECTION = "suse_register".freeze

    # Activate and probe storage
    def probe_storage
      Y2Storage::StorageManager.instance.activate(Y2Autoinstallation::ActivateCallbacks.new)
      Y2Storage::StorageManager.instance.probe
    end

    # Read modified profile
    #
    # When a profile is found at /tmp/profile/modified.xml, it will replace
    # the current loaded profile. The original autoinst.xml file will be replaced
    # by modified.xml (a backup will be kept as pre-autoinst.xml).
    #
    # @return [Symbol] :abort if profile could not be read; :found when it was loaded;
    #   :not_found if it does not exist
    def readModified
      textdomain "autoinst"
      if Yast::SCR.Read(path(".target.size"), Yast::AutoinstConfig.modified_profile) <= 0
        return :not_found
      end

      return :abort unless profile_checker.valid_modified_profile?

      if !Yast::Profile.ReadXML(Yast::AutoinstConfig.modified_profile) ||
          Yast::Profile.current == {}
        Yast::Popup.Error(
          _(
            "Error while parsing the control file.\n" \
            "Check the log files for more details or fix the\n" \
            "control file and try again.\n"
          )
        )
        return :abort
      end

      backup_autoinst
      update_autoinst
      @modified_profile = true
      :found
    end

    # Determine whether the profile was modified
    #
    # @return [Boolean] true if it was modified; false otherwise.
    def modified_profile?
      !!@modified_profile
    end

    # System registration
    #
    # @return [Boolean] true if succeeded.
    def suse_register
      return true unless registration_module_available? # do nothing

      register_section = Yast::Profile.current.fetch_as_hash(REGISTER_SECTION, nil)
      disabled_registration = (register_section || {})["do_registration"] == false

      # remove the registration section to not run it again in the 2nd when it is explicitly
      # disabled (no autoupgrade detection is needed in this case)
      Yast::Profile.remove_sections(REGISTER_SECTION) if disabled_registration

      # autoupgrade detects itself if system is registered and if needed do migration via scc
      if !disabled_registration && (register_section || Yast::Mode.autoupgrade)
        Yast::WFM.CallFunction(
          "scc_auto",
          ["Import", Yast::Profile.current[REGISTER_SECTION]]
        )
        return false unless Yast::WFM.CallFunction(
          "scc_auto",
          ["Write"]
        )

        # remove the registration section to not run it again in the 2nd stage
        Yast::Profile.remove_sections(REGISTER_SECTION)

        # failed relnotes download is not fatal, ignore ret code
        Yast::WFM.CallFunction("inst_download_release_notes")
      elsif semi_auto?("scc")
        Yast::WFM.CallFunction("inst_scc", ["enable_next" => true])
      end
      true
    end

    # Convenience method to check whether a particular client should be run to
    # be configured manually during the autoinstallation according to the
    # semi-automatic section
    #
    # @return [Boolean]
    def semi_auto?(name)
      general_section = Yast::Profile.current.fetch_as_hash("general")
      !!general_section["semi-automatic"]&.include?(name)
    end

    # Autosetup the network
    def autosetup_network
      # Prevent to be called twice in case of already configured
      return if @network_configured

      networking_section = Yast::Profile.current.fetch_as_hash("networking")
      Yast::WFM.CallFunction("lan_auto", ["Import", networking_section])

      # Import also the host section in order to resolve hosts only available
      # with the network configuration and the host entry
      if Yast::Profile.current.fetch_as_hash("host", nil)
        Yast::WFM.CallFunction("host_auto", ["Import", Yast::Profile.current.fetch_as_hash("host")])
      end

      if semi_auto?("networking")
        log.info("Networking manual setup before proposal")
        Yast::WFM.CallFunction(
          "inst_lan", ["enable_next" => true, "skip_detection" => true]
        )
        @network_before_proposal = true
      end

      if Yast::Profile.current.fetch_as_hash("proxy", nil)
        Yast::WFM.CallFunction("proxy_auto", ["Import", Yast::Profile.current["proxy"]])
        Yast::WFM.CallFunction("proxy_auto", ["Write"]) if network_before_proposal?
      end

      log.info("Networking setup before the proposal: #{network_before_proposal?}")
      Yast::WFM.CallFunction("lan_auto", ["Write"]) if network_before_proposal?

      # Clean-up the profile
      Yast::Profile.remove_sections(["networking", "host", "proxy"])

      @network_configured = true
    end

    # Convenience method to check whether the network configuration should be
    # written before the proposal
    #
    # @return [Boolean] true when network config should be written before the
    #   proposal; false when not
    def network_before_proposal?
      return @network_before_proposal unless @network_before_proposal.nil?

      networking_section = Yast::Profile.current.fetch_as_hash("networking")

      @network_before_proposal = networking_section.fetch("setup_before_proposal", false)
    end

    # Import and configure country specific data (timezone, language and
    # keyboard)
    def autosetup_country
      Yast::Language.Import(Yast::Profile.current.fetch_as_hash("language"))

      # Set Console font
      Yast::Installation.encoding = Yast::Console.SelectFont(Yast::Language.language)
      Yast::Installation.encoding = "UTF-8" if utf8_supported?

      unless Yast::Language.SwitchToEnglishIfNeeded(true)
        Yast::UI.SetLanguage(Yast::Language.language, Yast::Installation.encoding)
        Yast::WFM.SetLanguage(Yast::Language.language, "UTF-8")
      end

      if Yast::Profile.current.key?("timezone")
        Yast::Timezone.Import(Yast::Profile.current.fetch_as_hash("timezone"))
        Yast::Profile.remove_sections("timezone")
      end

      # bnc#891808: infer keyboard from language if needed
      if Yast::Profile.current.key?("keyboard")
        Yast::Keyboard.Import(Yast::Profile.current.fetch_as_hash("keyboard"), :keyboard)
        Yast::Profile.remove_sections("keyboard")
      elsif Yast::Profile.current.key?("language")
        Yast::Keyboard.Import(Yast::Profile.current.fetch_as_hash("language"), :language)
      end

      Yast::Profile.remove_sections("language") if Yast::Profile.current.key?("language")
    end

    def profile_checker
      Y2Autoinstallation::XmlChecks.instance
    end

    # Invokes autoyast setup for firewall
    def autosetup_firewall
      return if !Yast::Profile.current.fetch_as_hash("firewall", nil)

      # in some cases we need to postpone firewall configuration to the second stage
      # we also have to guarantee that firewall is not blocking second stage in this case
      firewall_section = if need_second_stage_run?
        { "enable_firewall" => false }
      else
        Yast::Profile.current.fetch_as_hash("firewall")
      end

      log.info("Importing Firewall settings from AY profile")
      Yast::WFM.CallFunction("firewall_auto", ["Import", firewall_section])

      Yast::Profile.remove_sections("firewall") if !need_second_stage_run?
    end

    def validate_security_policies
      target_config = Y2Security::SecurityPolicies::TargetConfig.new
      rules = Y2Security::SecurityPolicies::Manager.instance.failing_rules(target_config)
      return if rules.empty?

      y2issues = rules.map do |rule|
        message = "#{rule.id} #{rule.description}"
        Y2Issues::Issue.new(message, severity: :error)
      end
      Y2Issues.report(Y2Issues::List.new(y2issues))
    end

  private

    # Checks whether we need to run second stage handling
    def need_second_stage_run?
      Yast.import "Linuxrc"

      profile = Yast::Profile.current

      # We have a problem when
      # 1) running remote installation
      # 2) second stage was requested
      # 3) firewall was configured (somehow) and started via AY profile we can expect that
      # ssh / vnc port can be blocked.
      remote_installer = Yast::Linuxrc.usessh || Yast::Linuxrc.vnc
      second_stage_required = profile.dig("general", "mode", "second_stage")
      firewall_enabled = profile.dig("firewall", "enable_firewall")

      remote_installer && second_stage_required && firewall_enabled
    end

    def utf8_supported?
      (Yast::UI.GetDisplayInfo || {}).fetch("HasFullUtf8Support", true)
    end

    # Backup AutoYaST profile
    #
    # Copies autoinst.xml to pre-autoinst.xml.
    def backup_autoinst
      cpcmd = format(
        "mv %s %s",
        Yast::AutoinstConfig.profile_path,
        Yast::AutoinstConfig.profile_backup_path
      )
      log.info("copy original profile: #{cpcmd}")
      Yast::SCR.Execute(path(".target.bash"), cpcmd)
    end

    # Update AutoYaST profile
    #
    # Replaces autoinst.xml by modified.xml.
    def update_autoinst
      mvcmd = format(
        "mv %s %s",
        Yast::AutoinstConfig.modified_profile,
        Yast::AutoinstConfig.profile_path
      )
      log.info("moving modified profile: #{mvcmd}")
      Yast::SCR.Execute(path(".target.bash"), mvcmd)
    end

    # Checking if the yast2-registration module is available
    #
    # @return [Boolean] true if yast2-registration module is available
    def registration_module_available?
      begin
        require "registration/registration"
      rescue LoadError
        log.info "yast2-registration is not available"
        return false
      end
      true
    end
  end
end
