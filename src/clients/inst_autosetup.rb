# encoding: utf-8

# File:    clients/inst_autosetup.ycp
# Package: Auto-installation
# Summary: Setup and prepare system for auto-installation
# Authors: Anas Nashif <nashif@suse.de>
#          Uwe Gansert <ug@suse.de>
#
# $Id$
require "autoinstall/module_config_builder"
require "autoinstall/autosetup_helpers"

module Yast
  import "AutoinstConfig"

  class InstAutosetupClient < Client
    include Yast::Logger
    include Y2Autoinstallation::AutosetupHelpers

    Target = AutoinstConfigClass::Target

    def main
      Yast.import "Pkg"
      Yast.import "UI"
      textdomain "autoinst"

      Yast.import "AutoInstall"
      Yast.import "Installation"
      Yast.import "Profile"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "AutoinstStorage"
      Yast.import "AutoinstScripts"
      Yast.import "AutoinstGeneral"
      Yast.import "AutoinstSoftware"
      Yast.import "Popup"
      Yast.import "Arch"
      Yast.import "Timezone"
      Yast.import "Keyboard"
      Yast.import "Call"
      Yast.import "ProductControl"
      Yast.import "Language"
      Yast.import "Console"
      Yast.import "ServicesManager"
      Yast.import "Y2ModuleConfig"
      Yast.import "AutoinstFunctions"
      Yast.import "Wizard"

      Yast.include self, "autoinstall/ask.rb"

      @help_text = _(
        "<P>Please wait while the system is prepared for autoinstallation.</P>"
      )
      @progress_stages = [
        _("Execute pre-install user scripts"),
        _("Configure General Settings "),
        _("Set up language"),
        _("Configure security settings"),
        _("Create partition plans"),
        _("Configure Bootloader"),
        _("Registration"),
        _("Configure Software selections"),
        _("Configure Systemd Default Target"),
        _("Configure users and groups"),
        _("Import SSH keys/settings"),
        _("Confirm License")
      ]

      @progress_descriptions = [
        _("Executing pre-install user scripts..."),
        _("Configuring general settings..."),
        _("Setting up language..."),
        _("Configuring security settings"),
        _("Creating partition plans..."),
        _("Configuring Bootloader..."),
        _("Registering the system..."),
        _("Configuring Software selections..."),
        _("Configuring Systemd Default Target..."),
        _("Importing users and groups configuration..."),
        _("Importing SSH keys/settings..."),
        _("Confirming License...")
      ]

      Progress.New(
        _("Preparing System for Automated Installation"),
        "", # progress_title
        Builtins.size(@progress_stages), # progress bar length
        @progress_stages,
        @progress_descriptions,
        @help_text
      )


      return :abort if Popup.ConfirmAbort(:painless) if UI.PollInput == :abort


      Progress.NextStage

      # Pre-Scripts
      AutoinstScripts.Import(Ops.get_map(Profile.current, "scripts", {}))
      AutoinstScripts.Write("pre-scripts", false)

      # Reread Profile in case it was modified in pre-script
      # User has to create the new profile in a pre-defined
      # location for easy processing in pre-script.

      return :abort if readModified == :abort

      return :abort if Popup.ConfirmAbort(:painless) if UI.PollInput == :abort

      #
      # Partitioning and Storage
      #//////////////////////////////////////////////////////////////////////

      @modified = true
      begin
        askDialog
        # Pre-Scripts
        AutoinstScripts.Import(Ops.get_map(Profile.current, "scripts", {}))
        AutoinstScripts.Write("pre-scripts", false)
        @ret2 = readModified
        return :abort if @ret2 == :abort
        @modified = false if @ret2 == :not_found
        if Ops.greater_or_equal(
            SCR.Read(path(".target.size"), "/var/lib/YaST2/restart_yast"),
            0
          )
          return :restart_yast
        end
      end while @modified == true


      # reimport scripts, for the case <ask> has changed them
      AutoinstScripts.Import(Ops.get_map(Profile.current, "scripts", {}))
      #
      # Set workflow variables
      #
      Progress.NextStage

      # Merging selected product
      AutoinstSoftware.merge_product(AutoinstFunctions.selected_product)

      # configure general settings
      AutoinstGeneral.Import(Ops.get_map(Profile.current, "general", {}))
      Builtins.y2milestone(
        "general: %1",
        Ops.get_map(Profile.current, "general", {})
      )
      AutoinstGeneral.Write

      AutoinstConfig.network_before_proposal = false
      general_section = Profile.current["general"] || {}
      semiauto_network = general_section["semi-automatic"] &&
        general_section["semi-automatic"].include?("networking")

      if Profile.current["networking"] &&
          ( Profile.current["networking"]["setup_before_proposal"] ||
            semiauto_network ||
            !AutoinstConfig.second_stage()
            )
        if Profile.current["networking"]["setup_before_proposal"]
          Builtins.y2milestone("Networking setup before the proposal")
          AutoinstConfig.network_before_proposal = true
        elsif !AutoinstConfig.second_stage()
          # Second stage of installation will not be called but a
          # network configuration is available. So this will be written
          # during the general inst_finish process at the end of the
          # first stage. But for the installation workflow the linuxrc
          # network settings will be taken. (bnc#944942)
          Builtins.y2milestone(
            "Networking setup at the end of first installation stage")
        end
        Builtins.y2milestone(
          "Importing Network settings from configuration file")
        Call.Function(
          "lan_auto",
          ["Import", Ops.get_map(Profile.current, "networking", {})]
        )
      end

      if semiauto_network
        Builtins.y2milestone("Networking manual setup before proposal")
        Call.Function("inst_lan", ["enable_next" => true])
        AutoinstConfig.network_before_proposal = true
      end

      Call.Function("lan_auto", ["Write"]) if AutoinstConfig.network_before_proposal

      if Builtins.haskey(Profile.current, "add-on")
	Progress.Title(_("Handling Add-On Products..."))
        unless Call.Function(
            "add-on_auto",
            ["Import", Ops.get_map(Profile.current, "add-on", {})]
          )

          log.warn("User has aborted the installation.")
          return :abort
        end
        Call.Function("add-on_auto", ["Write"])

        # Recover partitioning settings that were removed by the add-on_auto client (bsc#1073548)
        Yast::AutoinstStorage.import_general_settings(general_section["storage"])

        # The entry "kexec_reboot" in the Product description can be set
        # by the AutoYaST configuration setting (general/forceboot) and should
        # not be reset by any other Product description file.
        # So we set it here again.
        # bnc#981434
        AutoinstGeneral.SetRebootAfterFirstStage
      end

      @use_utf8 = true # utf8 is default

      @displayinfo = UI.GetDisplayInfo
      if !Ops.get_boolean(@displayinfo, "HasFullUtf8Support", true)
        @use_utf8 = false # fallback to ascii
      end

      #
      # Set it in the Language module.
      #
      Progress.NextStage
      Progress.Title(_("Configuring language..."))
      Language.Import(Ops.get_map(Profile.current, "language", {}))

      #
      # Set Console font
      #
      Installation.encoding = Console.SelectFont(Language.language)

      if Ops.get_boolean(@displayinfo, "HasFullUtf8Support", true)
        Installation.encoding = "UTF-8"
      end

      UI.SetLanguage(Language.language, Installation.encoding)
      WFM.SetLanguage(Language.language, "UTF-8")

      if Builtins.haskey(Profile.current, "timezone")
        Timezone.Import(Ops.get_map(Profile.current, "timezone", {}))
      end
      # bnc#891808: infer keyboard from language if needed
      if Profile.current.has_key?("keyboard")
        Keyboard.Import(Profile.current["keyboard"] || {}, :keyboard)
      elsif Profile.current.has_key?("language")
        Keyboard.Import(Profile.current["language"] || {}, :language)
      end

      # one can override the <confirm> option by the commandline parameter y2confirm
      @tmp = Convert.to_string(
        SCR.Read(path(".target.string"), "/proc/cmdline")
      )
      if @tmp != nil &&
          Builtins.contains(Builtins.splitstring(@tmp, " \n"), "y2confirm")
        AutoinstConfig.Confirm = true
        Builtins.y2milestone("y2confirm found and confirm turned on")
      end


      return :abort if Popup.ConfirmAbort(:painless) if UI.PollInput == :abort

      # moved here from autoinit for fate #301193
      # needs testing
      if Arch.s390
        dasd_or_zfcp = Profile.current.key?("dasd") || Profile.current.key?("zfcp")
        if Builtins.haskey(Profile.current, "dasd")
          Builtins.y2milestone("dasd found")
          if Call.Function("dasd_auto", ["Import", Ops.get_map(Profile.current, "dasd", {})])
            Call.Function("dasd_auto", [ "Write" ])
          end
        end
        if Builtins.haskey(Profile.current, "zfcp")
          Builtins.y2milestone("zfcp found")
          if Call.Function("zfcp_auto", ["Import", Ops.get_map(Profile.current, "zfcp", {})])
            Call.Function("zfcp_auto", [ "Write" ])
          end
        end
      end

      Progress.NextStage

      # Importing security settings
      autosetup_security
      return :abort if Popup.ConfirmAbort(:painless) if UI.PollInput == :abort

      Progress.NextStage

      probe_storage if modified_profile? || dasd_or_zfcp

      if Profile.current["partitioning_advanced"] && !Profile.current["partitioning_advanced"].empty?
        write_storage = AutoinstStorage.ImportAdvanced(Profile.current["partitioning_advanced"])
      else
        write_storage = AutoinstStorage.Import(Profile.current["partitioning"])
      end

      return :abort unless write_storage

      semiauto_partitions = general_section["semi-automatic"] &&
        general_section["semi-automatic"].include?("partitioning")

      if semiauto_partitions
        Builtins.y2milestone("Partitioning manual setup")
        # Yes, do not set Storage testsuite here as we want really GUI with proposal
        Call.Function("inst_disk_proposal", ["enable_next" => true])
        write_storage = true
      end


      if write_storage &&
          !AutoinstStorage.Write
        Report.Error(_("Error while configuring partitions.\nTry again.\n"))
        Builtins.y2error("Aborting...")
        return :abort
      end

      # Bootloader
      # The bootloader has to be called before software selection.
      # So the software selection is aware and can manage packages
      # needed by the bootloader (bnc#876161)

      return :abort if Popup.ConfirmAbort(:painless) if UI.PollInput == :abort
      Progress.NextStage

      return :abort unless WFM.CallFunction(
        "bootloader_auto",
        ["Import", Ops.get_map(Profile.current, "bootloader", {})]
      )

      # Registration
      # FIXME: There is a lot of duplicate code with inst_autoupgrade.

      return :abort if Popup.ConfirmAbort(:painless) if UI.PollInput == :abort
      Progress.NextStage

      # The configuration_management has to be called before software selection.
      # So the software selection is aware and can manage packages
      # needed by the configuration_management.
      if Profile.current["configuration_management"]
        return :abort unless WFM.CallFunction(
          "configuration_management_auto",
          ["Import", Profile.current["configuration_management"]]
        )
        # Do not start it in second installation stage again.
        # Provisioning will already be called in the first stage.
        Profile.remove_sections("configuration_management")
      end

      # Register system
      return :abort unless suse_register

      # Software

      return :abort if Popup.ConfirmAbort(:painless) if UI.PollInput == :abort

      Progress.NextStage

      # Evaluating package and patterns selection.
      # Selection will be stored in PackageAI.
      AutoinstSoftware.Import(Ops.get_map(Profile.current, "software", {}))

      # Add additional packages in order to run YAST modules which
      # have been defined in the AutoYaST configuration file.
      # Selection will be stored in PackageAI.
      add_yast2_dependencies if AutoinstFunctions.second_stage_required?

      # Adding selections (defined in PackageAI) to libzypp and solving
      # package dependencies.
      if !AutoinstSoftware.Write
        Report.Error(
          _("Error while configuring software selections.\nTry again.\n")
        )
        Builtins.y2error("Aborting...")
        return :abort
      end
      # fate #301321 - AutoYaST imaging support
      # no generic images, just the ones the manual installation would use too, to speed up
      # installation
      #
      # no check if section is available makes product default possible
      Call.Function(
        "deploy_image_auto",
        ["Import", Ops.get_map(Profile.current, "deploy_image", {})]
      )
      Call.Function("deploy_image_auto", ["Write"])


      # SLES only
      if Builtins.haskey(Profile.current, "kdump")
        Call.Function(
          "kdump_auto",
          ["Import", Ops.get_map(Profile.current, "kdump", {})]
        )
      end

      Progress.NextStage

      if Profile.current.has_key? ('runlevel')
        # still supporting old format "runlevel"
        ServicesManager.import(Profile.current['runlevel'])
        # Do not start it in second installation stage again.
        # Writing will be called in inst_finish.
        Profile.remove_sections("runlevel")
      elsif Profile.current.has_key? ('services-manager')
        ServicesManager.import(Profile.current['services-manager'])
        # Do not start it in second installation stage again.
        # Writing will be called in inst_finish.
        Profile.remove_sections("services-manager")
      else
        # We will have to set default entries which are defined
        # in the import call of ServicesManager
        ServicesManager.import({})
      end

      #
      # Import users configuration from the profile
      #
      Progress.NextStage
      autosetup_users

      #
      # Import profile settings for copying SSH keys from a
      # previous installation
      #
      Progress.NextStage
      if Profile.current["ssh_import"]
        config = Profile.current["ssh_import"]
        Profile.remove_sections("ssh_import")
        return :abort unless WFM.CallFunction(
          "ssh_import_auto",
          ["Import", config]
        )
      end

      #
      # Checking Base Product licenses
      #
      Progress.NextStage
      if general_section["mode"] && general_section["mode"].fetch( "confirm_base_product_license", false )
        result = nil
        while result != :next
          result = WFM.CallFunction("inst_product_license", [{"enable_back"=>false}])
          return :abort if result == :abort && Yast::Popup.ConfirmAbort(:painless)
        end
      end

      # Results of imported values semantic check.
      return :abort unless AutoInstall.valid_imported_values

      Progress.Finish

      @ret = ProductControl.RunFrom(ProductControl.CurrentStep + 1, true)

      return :finish if @ret == :next
      @ret
    end

    # Import Users configuration from profile
    def autosetup_users
      users_config = ModuleConfigBuilder.build(Y2ModuleConfig.getModuleConfig("users"), Profile.current)
      if users_config
        Profile.remove_sections(users_config.keys)
        Call.Function("users_auto", ["Import", users_config])
      end
    end

    # Import security settings from profile
    def autosetup_security
      security_config = Profile.current["security"]
      if security_config
        # Do not start it in second installation stage again.
        # Writing will be called in inst_finish.
        Profile.remove_sections("security")
        Call.Function("security_auto", ["Import", security_config])
      end
    end

    # Add YaST2 packages dependencies
    def add_yast2_dependencies
      keys = Profile.current.keys.select do |k|
        Profile.current[k].is_a?(Array)||Profile.current[k].is_a?(Hash)
      end
      AutoinstSoftware.AddYdepsFromProfile(keys)
    end
  end
end

Yast::InstAutosetupClient.new.main
