# encoding: utf-8

#  * File:
#  * Package:     Auto-installation
#  * Author:      Uwe Gansert <ug@suse.de>
#  * Summary:
#  *
#  * Changes:     * initial
#    0.2:         * added Pkg::TargetInit
#    0.3:         * support for <post-packages>
#    0.4:         * support for the <ask> feature
#    0.5:         * support for the new "keep install network"
#                   feature of 10.3
#  * Version:     0.5
#  * $Id$
#
#    this client can be called from a running system,
#    to do the autoyast configuration.
#    You have to provide a profile and autoyast will
#    configure your system like in the profile.
#    Only stage2 configuration can be done.
#    yast2 ./ayast_setup.rb setup filename=/tmp/my.xml
module Yast
  class AyastSetupClient < Client
    include Yast::Logger

    def main
      Yast.import "Pkg"
      textdomain "autoinst"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("ayast_setup started")

      Yast.import "Profile"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "Mode"
      Yast.import "CommandLine"
      Yast.import "Stage"
      Yast.import "AutoInstall"
      Yast.import "AutoinstSoftware"
      Yast.import "PackageSystem"
      Yast.import "AutoinstData"
      Yast.import "Lan"

      @dopackages = true


      @cmdline = {
        "id"         => "ayast_setup",
        "help"       => _(
          "Client for AutoYaST configuration on the running system"
        ),
        "guihandler" => fun_ref(method(:GUI), "symbol ()"),
        "actions"    => {
          "setup" => {
            "handler" => fun_ref(
              method(:openFile),
              "boolean (map <string, any>)"
            ),
            "help"    => _("Configure the system using given AutoYaST profile"),
            "example" => "setup filename=/path/to/profile dopackages=no"
          }
        },
        "options"    => {
          "filename"   => {
            "type" => "string",
            "help" => _("Path to AutoYaST profile")
          },
          "dopackages" => {
            "type"     => "enum",
            "typespec" => ["yes", "no"],
            "help"     => _("enable/disable all package handling")
          }
        },
        "mappings"   => { "setup" => ["filename", "dopackages"] }
      }

      @ret = CommandLine.Run(@cmdline)

      Builtins.y2debug("ret = %1", @ret)
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("ayast_setup finished")

      nil
    end

    def GUI
      Mode.SetUI("commandline")
      CommandLine.Error(_("Empty parameter list"))
      :dummy
    end

    def Setup
      AutoInstall.Save
      Wizard.CreateDialog
      Mode.SetMode("autoinstallation")
      Stage.Set("continue")

      # IPv6 settings will be written despite the have been
      # changed or not. So we have to read them at first.
      # FIXME: Move it to Lan.rb and remove the Lan import dependency.
      Lan.ipv6 = Lan.readIPv6

      WFM.CallFunction("inst_autopost", [])
      postPackages = Ops.get_list(
        Profile.current,
        ["software", "post-packages"],
        []
      )
      postPackages = Builtins.filter(postPackages) do |p|
        !PackageSystem.Installed(p)
      end
      AutoinstSoftware.addPostPackages(postPackages)

      AutoinstData.post_patterns = Ops.get_list(
        Profile.current,
        ["software", "post-patterns"],
        []
      )

      # the following is needed since 10.3
      # otherwise the already configured network gets removed
      if !Builtins.haskey(Profile.current, "networking")
        Profile.current = Builtins.add(
          Profile.current,
          "networking",
          { "keep_install_network" => true }
        )
      end

      if @dopackages
        Pkg.TargetInit("/", false)
        WFM.CallFunction("inst_rpmcopy", [])
      end
      WFM.CallFunction("inst_autoconfigure", [])

      # Restarting autoyast-initscripts.service in order to run
      # init-scripts in the installed system.
      cmd = "systemctl restart autoyast-initscripts.service"
      ret = SCR.Execute(path(".target.bash_output"), cmd)
      log.info "command \"#{cmd}\" returned #{ret}"
      nil
    end

    def openFile(options)
      options = deep_copy(options)
      if Ops.get(options, "filename") == nil
        CommandLine.Error(_("Path to AutoYaST profile must be set."))
        return false
      end
      if Ops.get_string(options, "dopackages", "yes") == "no"
        @dopackages = false
      end
      if SCR.Read(
          path(".target.lstat"),
          Ops.get_string(options, "filename", "")
        ) == {} ||
          !Profile.ReadXML(Ops.get_string(options, "filename", ""))
        Mode.SetUI("commandline")
        CommandLine.Print(
          _(
            "Error while parsing the control file.\n" +
              "Check the log files for more details or fix the\n" +
              "control file and try again.\n"
          )
        )
        return false
      end

      Setup()
      true
    end
  end
end

Yast::AyastSetupClient.new.main
