# Copyright (c) [2020] SUSE LLC
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

Yast.import "AutoinstClone"
Yast.import "Profile"
Yast.import "XML"
Yast.import "Popup"
Yast.import "ProductControl"
Yast.import "CommandLine"
Yast.import "Y2ModuleConfig"
Yast.import "Mode"
Yast.import "FileUtils"
Yast.import "Report"
Yast.import "Installation"
Yast.import "PackageSystem"

module Y2Autoinstallation
  module Clients
    # This client is responsible for cloning the system, generating an AutoYaST profile.
    class CloneSystem < Yast::Client
      include Yast::Logger

      def initialize
        textdomain "autoinst"
      end

      # Handle the command line options and clone the system
      def main
        if Yast::Mode.normal
          if !Yast::PackageSystem.Installed("autoyast2")
            ret = Yast::PackageSystem.InstallAll(["autoyast2"])
            # The modules/clients has to be reloaded. So the export
            # will be restarted.
            if ret
              Yast::SCR.Execute(
                path(".target.bash"),
                "touch #{Installation.restart_file}"
              )
            end
            return
          elsif Yast::FileUtils.Exists(Yast::Installation.restart_file)
            Yast::SCR.Execute(path(".target.remove"), Yast::Installation.restart_file)
          end
        end

        modules_list = Yast::Y2ModuleConfig.clonable_modules.keys.join(" ")

        if [NilClass, Hash].any? { |c| Yast::WFM.Args.first.is_a?(c) }
          params = Yast::WFM.Args.first || {}
          doClone(params)
        else
          cmdline = {
            "id"         => "clone_system",
            "help"       => _(
              "Client for creating an AutoYaST profile based on the currently running system"
            ),
            "guihandler" => fun_ref(method(:GUI), "symbol ()"),
            "actions"    => {
              "modules" => {
                "handler" => fun_ref(
                  method(:doClone),
                  "boolean (map <string, any>)"
                ),
                "help"    => format(_("known modules: %s"), modules_list),
                "example" => "modules clone=software,partitioning"
              }
            },
            "options"    => {
              "clone"    => {
                "type" => "string",
                "help" => _("comma separated list of modules to clone")
              },
              "filename" => {
                "type" => "string",
                "help" => "filename=OUTPUT_FILE"
              }
            },
            "mappings"   => { "modules" => ["clone", "filename"] }
          }

          ret = Yast::CommandLine.Run(cmdline)
          log.debug("ret = #{ret}")
        end

        log.info("----------------------------------------")
        log.info("clone_system finished")

        nil
      end

      def GUI
        Yast::Mode.SetUI("commandline")
        Yast::CommandLine.Error(_("Empty parameter list"))
        :dummy
      end

      # @return [String] Default filename to write the profile to
      DEFAULT_FILENAME = "/root/autoinst.xml".freeze

      def doClone(options = DEFAULT_FILENAME)
        filename = options["filename"] || "/root/autoinst.xml"

        # Autoyast overwriting an already existing config file.
        # The warning is only needed while calling "yast clone_system". It is not
        # needed in the installation workflow where it will be checked by the file selection box
        # directly. (bnc#888546)
        if Yast::Mode.normal && Yast::FileUtils.Exists(filename)
          # TRANSLATORS: Warning that an already existing autoyast configuration file
          #              will be overwritten.
          if !Yast::Popup.ContinueCancel(_("File %s exists! Really overwrite?") % filename)
            return false
          end
        end

        Yast::Popup.ShowFeedback(
          _("Cloning the system..."),
          # TRANSLATORS: %s is path where profile can be found
          _("The resulting autoyast profile can be found in %s.") % filename
        )

        Yast::AutoinstClone.additional =
          if options["clone"]
            options["clone"].split(",")
          else
            Yast::ProductControl.clone_modules
          end
        Yast::AutoinstClone.Process
        Yast::XML.YCPToXMLFile(:profile, Yast::Profile.current, filename)
        Yast::Popup.ClearFeedback
        true
      end
    end
  end
end
