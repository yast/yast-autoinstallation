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

require "yast"
Yast.import "Profile"
Yast.import "Wizard"
Yast.import "Mode"
Yast.import "CommandLine"
Yast.import "Stage"
Yast.import "AutoInstall"
Yast.import "AutoinstSoftware"
Yast.import "Package"
Yast.import "AutoinstData"
Yast.import "AutoinstGeneral"
Yast.import "Lan"
Yast.import "Pkg"

module Y2Autoinstall
  module Clients
    module AyastSetup
      include Yast::Logger
      include Yast::I18n

      Ops = Yast::Ops
      SCR = Yast::SCR
      WFM = Yast::WFM
      Profile  = Yast::Profile
      Builtins = Yast::Builtins
      def Setup
        textdomain "autoinst"
        Yast::AutoInstall.Save
        Yast::Wizard.CreateDialog
        Yast::Mode.SetMode("autoinstallation")
        Yast::Stage.Set("continue")

        Yast::AutoinstGeneral.Import(Yast::Profile.current.fetch("general", {}))

        # IPv6 settings will be written despite the have been
        # changed or not. So we have to read them at first.
        # FIXME: Move it to Lan.rb and remove the Lan import dependency.
        Yast::Lan.ipv6 = Yast::Lan.readIPv6

        WFM.CallFunction("inst_autopost", [])
        postPackages = Ops.get_list(
          Profile.current,
          ["software", "post-packages"],
          []
        )

        postPackages = Builtins.filter(postPackages) do |p|
          !Yast::Package.Installed(p)
        end
        Yast::AutoinstSoftware.addPostPackages(postPackages)

        Yast::AutoinstData.post_patterns = Ops.get_list(
          Profile.current,
          ["software", "post-patterns"],
          []
        )

        if @dopackages
          Yast::Pkg.TargetInit("/", false)
          WFM.CallFunction("inst_rpmcopy", [])
        end
        WFM.CallFunction("inst_autoconfigure", [])

        restart_initscripts
        nil
      end

      def openFile(options)
        textdomain "autoinst"
        options = deep_copy(options)
        if Ops.get(options, "filename").nil?
          Yast::CommandLine.Error(_("Path to AutoYaST profile must be set."))
          return false
        end
        @dopackages = false if Ops.get_string(options, "dopackages", "yes") == "no"
        if SCR.Read(
          path(".target.lstat"),
          Ops.get_string(options, "filename", "")
        ) == {} ||
            !Profile.ReadXML(Ops.get_string(options, "filename", ""))
          Yast::Mode.SetUI("commandline")
          Yast::CommandLine.Print(
            _(
              "Error while parsing the control file.\n" \
                "Check the log files for more details or fix the\n" \
                "control file and try again.\n"
            )
          )
          return false
        end

        Setup()
        true
      end

    private

      def restart_initscripts
        # Restarting autoyast-initscripts.service in order to run
        # init-scripts in the installed system.
        cmd = "systemctl restart autoyast-initscripts.service"
        ret = SCR.Execute(path(".target.bash_output"), cmd)
        log.info "command \"#{cmd}\" returned #{ret}"
      end
    end
  end
end
