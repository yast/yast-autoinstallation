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
require "autoinstall/activate_callbacks"
require "autoinstall/xml_checks"

Yast.import "Profile"

module Y2Autoinstallation
  # This module defines some methods that are used in {Yast::InstAutosetupClient}
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
        puts "NOT FOUND"
        return :not_found
      end

      return :abort unless Y2Autoinstallation::XmlChecks.valid_modified_profile?

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

      # autoupgrade detects itself if system is registered and if needed do migration via scc
      if Yast::Profile.current[REGISTER_SECTION] || Yast::Mode.autoupgrade
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

    # Convenienve method to check whether a particular client should be run to
    # be configured manually during the autoinstallation according to the
    # semi-automatic section
    #
    # @return [Boolean]
    def semi_auto?(name)
      general_section = Yast::Profile.current["general"] || {}
      !!general_section["semi-automatic"]&.include?(name)
    end

    # Autosetup the network
    def autosetup_network
      # Prevent to be called twice in case of already configured
      return if @network_configured

      if Yast::Profile.current["networking"]
        if network_before_proposal?
          log.info("Networking setup before the proposal")
        else
          log.info("Networking setup at the end of first installation stage")
        end

        log.info("Importing Network settings from configuration file")
        Yast::WFM.CallFunction("lan_auto", ["Import", Yast::Profile.current["networking"]])
        Yast::Profile.remove_sections("networking")

        # Import also the host section in order to resolve hosts only available
        # with the network configuration and the host entry
        if Yast::Profile.current["host"] && network_before_proposal?
          Yast::WFM.CallFunction("host_auto", ["Import", Yast::Profile.current["host"]])
          Yast::Profile.remove_sections("host")
        end
      end

      if semi_auto?("networking")
        log.info("Networking manual setup before proposal")
        Yast::WFM.CallFunction("inst_lan", ["enable_next" => true])
        @network_before_proposal = true
      end

      Yast::WFM.CallFunction("lan_auto", ["Write"]) if network_before_proposal?
      @network_configured = true
    end

    # Convenience method to check whether the network configuration should be
    # written before the proposal
    #
    # @return [Boolean] true when network config should be written before the
    #   proposal; false when not
    def network_before_proposal?
      return @network_before_proposal unless @network_before_proposal.nil?

      networking_section = Yast::Profile.current["networking"] || {}

      @network_before_proposal = networking_section.fetch("setup_before_proposal", false)
    end

  private

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
