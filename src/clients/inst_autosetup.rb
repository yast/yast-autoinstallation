# encoding: utf-8

# File:    clients/inst_autosetup.ycp
# Package: Auto-installation
# Summary: Setup and prepare system for auto-installation
# Authors: Anas Nashif <nashif@suse.de>
#          Uwe Gansert <ug@suse.de>
#
# $Id$
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
        _("Configure Software selections"),
        _("Configure Bootloader"),
        _("Configure Systemd Default Target")
      ]

      @progress_descriptions = [
        _("Executing pre-install user scripts..."),
        _("Configuring general settings..."),
        _("Setting up language..."),
        _("Creating partition plans..."),
        _("Configuring Software selections..."),
        _("Configuring Bootloader..."),
        _("Configuring Systemd Default Target...")
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

      if Profile.current["networking"]
        Builtins.y2milestone("Networking setup before the proposal")
        Call.Function(
          "lan_auto",
          ["Import", Ops.get_map(Profile.current, "networking", {})]
        )
        Call.Function("lan_auto", ["Write"])
      end

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
      if Builtins.haskey(Profile.current, "keyboard")
        Keyboard.Import(Ops.get_map(Profile.current, "keyboard", {}))
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
          Call.Function(
            "dasd_auto",
            ["Import", Ops.get_map(Profile.current, "dasd", {})]
          )
        end
        if Builtins.haskey(Profile.current, "zfcp")
          Builtins.y2milestone("zfcp found")
          Call.Function(
            "zfcp_auto",
            ["Import", Ops.get_map(Profile.current, "zfcp", {})]
          )
        end
      end


      Progress.NextStage
      # if one modifies the partition table in a pre script, we will
      # recognize this now
      Storage.ReReadTargetMap

      # No partitioning in the profile means yast2-storage proposal (hmmmm.....)
      if Ops.greater_than(
          Builtins.size(Ops.get_list(Profile.current, "partitioning", [])),
          0
        )
        AutoinstStorage.Import(
          Ops.get_list(Profile.current, "partitioning", [])
        )
      elsif Ops.greater_than(
          Builtins.size(
            Ops.get_map(Profile.current, "partitioning_advanced", {})
          ),
          0
        )
        AutoinstStorage.ImportAdvanced(
          Ops.get_map(Profile.current, "partitioning_advanced", {})
        )
      else
        Storage.SetTestsuite(true) # FIXME: *urgs*
        WFM.CallFunction("inst_disk_proposal", [true, true]) # FIXME: fragile?
        Storage.SetTestsuite(false) # *urgs* again
      end

      if (Ops.greater_than(
          Builtins.size(Ops.get_list(Profile.current, "partitioning", [])),
          0
        ) ||
          Ops.greater_than(
            Builtins.size(
              Ops.get_map(Profile.current, "partitioning_advanced", {})
            ),
            0
          )) &&
          !AutoinstStorage.Write
        Report.Error(_("Error while configuring partitions.\nTry again.\n"))
        Builtins.y2error("Aborting...")
        return :abort
      end
      AutoinstRAID.Write if AutoinstRAID.Init
      AutoinstLVM.Write if AutoinstLVM.Init



      # Software

      return :abort if Popup.ConfirmAbort(:painless) if UI.PollInput == :abort

      Progress.NextStage
      AutoinstSoftware.Import(Ops.get_map(Profile.current, "software", {}))
      keys = Profile.current.keys.select do |k|
        Profile.current[k].is_a?(Array)||Profile.current[k].is_a?(Hash)
      end
      AutoinstSoftware.AddYdepsFromProfile(keys)

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


      # Bootloader

      return :abort if Popup.ConfirmAbort(:painless) if UI.PollInput == :abort
      Progress.NextStage

      BootCommon.getLoaderType(true)
      Bootloader.Import(
        AI2Export(Ops.get_map(Profile.current, "bootloader", {}))
      )
      BootCommon.DetectDisks
      Builtins.y2debug("autoyast: Proposing - fix")
      Bootloader.Propose
      Builtins.y2debug("autoyast: Proposing done")

      # SLES only
      if Builtins.haskey(Profile.current, "kdump")
        Call.Function(
          "kdump_auto",
          ["Import", Ops.get_map(Profile.current, "kdump", {})]
        )
      end

      LanUdevAuto.Import(Ops.get_map(Profile.current, "networking", {}))

      Progress.NextStage

      if Profile.current['runlevel'] && Profile.current['runlevel']['default']
        default_runlevel = Profile.current['runlevel']['default'].to_i
        @default_target = default_runlevel == 5 ? Target::GRAPHICAL : Target::MULTIUSER
        Builtins.y2milestone("Accepting runlevel '#{default_runlevel}' as default target '#{@default_target}'")
      else
        @default_target = Profile.current['default_target'].to_s
      end

      Builtins.y2milestone("autoyast - configured default target: '#{@default_target}'")

      if !@default_target.empty?
        SystemdTarget.default_target = @default_target
      else
        SystemdTarget.default_target = Installation.x11_setup_needed &&
          Arch.x11_setup_needed &&
          Pkg.IsSelected("xorg-x11-server") ? Target::GRAPHICAL : Target::MULTIUSER
      end

      Builtins.y2milestone(
        "autoyast - setting default target to: #{SystemdTarget.default_target}"
      )

      #    AutoInstall::PXELocalBoot();
      AutoInstall.TurnOff
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
  end
end

Yast::InstAutosetupClient.new.main
