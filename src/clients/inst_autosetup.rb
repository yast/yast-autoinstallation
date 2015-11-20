# encoding: utf-8

# File:    clients/inst_autosetup.ycp
# Package: Auto-installation
# Summary: Setup and prepare system for auto-installation
# Authors: Anas Nashif <nashif@suse.de>
#          Uwe Gansert <ug@suse.de>
#
# $Id$
require "autoinstall/module_config_builder"
module Yast
  import "AutoinstConfig"

  class InstAutosetupClient < Client

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
      Yast.import "Bootloader"
      Yast.import "BootCommon"
      Yast.import "Popup"
      Yast.import "Arch"
      Yast.import "AutoinstLVM"
      Yast.import "AutoinstRAID"
      Yast.import "Storage"
      Yast.import "Timezone"
      Yast.import "Keyboard"
      Yast.import "Call"
      Yast.import "ProductControl"
      Yast.import "LanUdevAuto"
      Yast.import "Language"
      Yast.import "Console"
      Yast.import "ServicesManager"
      Yast.import "Y2ModuleConfig"
      Yast.import "AutoinstFunctions"

      Yast.include self, "bootloader/routines/autoinstall.rb"
      Yast.include self, "autoinstall/ask.rb"

      @help_text = _(
        "<P>Please wait while the system is prepared for autoinstallation.</P>"
      )
      @progress_stages = [
        _("Execute pre-install user scripts"),
        _("Configure General Settings "),
        _("Set up language"),
        _("Create partition plans"),
        _("Configure Bootloader"),
        _("Registration"),
        _("Configure Software selections"),
        _("Configure Systemd Default Target"),
        _("Configure users and groups")
      ]

      @progress_descriptions = [
        _("Executing pre-install user scripts..."),
        _("Configuring general settings..."),
        _("Setting up language..."),
        _("Creating partition plans..."),
        _("Configuring Bootloader..."),
        _("Registering the system..."),
        _("Configuring Software selections..."),
        _("Configuring Systemd Default Target..."),
        _("Importing users and groups configuration...")
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

      # configure general settings
      AutoinstGeneral.Import(Ops.get_map(Profile.current, "general", {}))
      Builtins.y2milestone(
        "general: %1",
        Ops.get_map(Profile.current, "general", {})
      )
      AutoinstGeneral.Write

      write_network = false
      general_section = Profile.current["general"] || {}
      semiauto_network = general_section["semi-automatic"] &&
        general_section["semi-automatic"].include?("networking")

      if Profile.current["networking"] &&
          ( Profile.current["networking"]["setup_before_proposal"] ||
            semiauto_network ||
            !AutoinstConfig.second_stage()
            )
        Builtins.y2milestone(
          "Importing Network settings from configuration file")
        Call.Function(
          "lan_auto",
          ["Import", Ops.get_map(Profile.current, "networking", {})]
        )
        if Profile.current["networking"]["setup_before_proposal"]
          Builtins.y2milestone("Networking setup before the proposal")
          write_network = true
        elsif !AutoinstConfig.second_stage()
          # Second stage of installation will not be called but a
          # network configuration is available. So this will be written
          # while the general inst_finish process at the end of the
          # first stage. But for the installation workflow the linuxrc
          # network settings will be taken. (bnc#944942)
          Builtins.y2milestone(
            "Networking setup at the end of first installation stage")
        end
      end

      if semiauto_network
        Builtins.y2milestone("Networking manual setup before proposal")
        Call.Function("inst_lan", ["enable_next" => true])
        write_network = true
      end

      Call.Function("lan_auto", ["Write"]) if write_network

      if Builtins.haskey(Profile.current, "add-on")
	Progress.Title(_("Handling Add-On Products..."))
        Call.Function(
          "add-on_auto",
          ["Import", Ops.get_map(Profile.current, "add-on", {})]
        )
        Call.Function("add-on_auto", ["Write"])
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
      if Arch.s390 && AutoinstConfig.remoteProfile == true
        Builtins.y2milestone("arch=s390 and remote_profile=true")
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
      # if one modifies the partition table in a pre script, we will
      # recognize this now
      Storage.ReReadTargetMap

      if Profile.current["partitioning"] && !Profile.current["partitioning"].empty?
        AutoinstStorage.Import(Profile.current["partitioning"])
        write_storage = true
      elsif Profile.current["partitioning_advanced"] && !Profile.current["partitioning_advanced"].empty?
        AutoinstStorage.ImportAdvanced(Profile.current["partitioning_advanced"])
        write_storage = true
      # No partitioning in the profile means yast2-storage proposal (hmmmm.....)
      else
        Storage.SetTestsuite(true) # FIXME: *urgs*
        WFM.CallFunction("inst_disk_proposal", [true, true]) # FIXME: fragile?
        Storage.SetTestsuite(false) # *urgs* again
      end

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
      AutoinstRAID.Write if AutoinstRAID.Init
      AutoinstLVM.Write if AutoinstLVM.Init


      # Bootloader
      # The bootloader has to be called before software selection.
      # So the software selection can take care about packages
      # needed by the bootloader (bnc#876161)

      return :abort if Popup.ConfirmAbort(:painless) if UI.PollInput == :abort
      Progress.NextStage

      BootCommon.getLoaderType(true)
      return :abort unless WFM.CallFunction(
        "bootloader_auto",
        ["Import", Ops.get_map(Profile.current, "bootloader", {})]
      )

      # Registration
      # FIXME: There is a lot of duplicate code with inst_autoupgrade.

      return :abort if Popup.ConfirmAbort(:painless) if UI.PollInput == :abort
      Progress.NextStage

      if Profile.current["suse_register"]
        return :abort unless WFM.CallFunction(
          "scc_auto",
          ["Import", Profile.current["suse_register"]]
        )
        return :abort unless WFM.CallFunction(
          "scc_auto",
          ["Write"]
        )
	# failed relnotes download is not fatal, ignore ret code
	WFM.CallFunction("inst_download_release_notes")
      elsif general_section["semi-automatic"] &&
          general_section["semi-automatic"].include?("scc")

        Call.Function("inst_scc", ["enable_next" => true])
      end

      # Software

      return :abort if Popup.ConfirmAbort(:painless) if UI.PollInput == :abort

      Progress.NextStage

      # Evaluating package and patterns selection.
      # Selection will stored in PackageAI.
      AutoinstSoftware.Import(Ops.get_map(Profile.current, "software", {}))

      # Add additional packages in order to run YAST modules which
      # has been defined the AutoYaST configuration file.
      # Selection will stored in PackageAI.
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

      LanUdevAuto.Import(Ops.get_map(Profile.current, "networking", {}))

      Progress.NextStage

      if Profile.current.has_key? ('runlevel')
        # still supporting old format "runlevel"
        ServicesManager.import(Profile.current['runlevel'])
      elsif Profile.current.has_key? ('services-manager')
        ServicesManager.import(Profile.current['services-manager'])
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

      Progress.Finish

      @ret = ProductControl.RunFrom(
        Ops.add(ProductControl.CurrentStep, 1),
        true
      )
      return :finish if @ret == :next
      @ret
    end

    def readModified
      if Ops.greater_than(
          SCR.Read(path(".target.size"), AutoinstConfig.modified_profile),
          0
        )
        if !Profile.ReadXML(AutoinstConfig.modified_profile) ||
            Profile.current == {}
          Popup.Error(
            _(
              "Error while parsing the control file.\n" +
                "Check the log files for more details or fix the\n" +
                "control file and try again.\n"
            )
          )
          return :abort
        end
        cpcmd = Builtins.sformat(
          "mv %1 %2",
          "/tmp/profile/autoinst.xml",
          "/tmp/profile/pre-autoinst.xml"
        )
        Builtins.y2milestone("copy original profile: %1", cpcmd)
        SCR.Execute(path(".target.bash"), cpcmd)

        cpcmd = Builtins.sformat(
          "mv %1 %2",
          AutoinstConfig.modified_profile,
          "/tmp/profile/autoinst.xml"
        )
        Builtins.y2milestone("moving modified profile: %1", cpcmd)
        SCR.Execute(path(".target.bash"), cpcmd)
        return :found
      end
      :not_found
    end

    # Import Users configuration from profile
    def autosetup_users
      users_config = ModuleConfigBuilder.build(Y2ModuleConfig.getModuleConfig("users"), Profile.current)
      if users_config
        Profile.remove_sections(users_config.keys)
        Call.Function("users_auto", ["Import", users_config])
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
