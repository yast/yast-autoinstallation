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
require "fileutils"

require "autoinstall/entries/registry"

Yast.import "AutoinstClone"
Yast.import "Profile"
Yast.import "XML"
Yast.import "Popup"
Yast.import "ProductControl"
Yast.import "CommandLine"
Yast.import "Mode"
Yast.import "FileUtils"
Yast.import "Report"
Yast.import "Installation"
Yast.import "Package"

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
          if !Yast::Package.Installed("autoyast2")
            ret = Yast::Package.InstallAll(["autoyast2"])
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

        registry = Y2Autoinstallation::Entries::Registry.instance
        modules_list = registry.descriptions.select(&:clonable?).map(&:resource_name).join(" ")

        if [NilClass, Hash].any? { |c| Yast::WFM.Args.first.is_a?(c) }
          params = Yast::WFM.Args.first || {}
          clone_system(params)
        else
          cmdline = {
            "id"       => "clone_system",
            "help"     => _(
              "Client for creating an AutoYaST profile based on the currently running system"
            ),
            "actions"  => {
              "modules" => {
                "handler" => fun_ref(
                  method(:clone_system),
                  "boolean (map <string, any>)"
                ),
                "help"    => format(_("known modules: %s"), modules_list),
                "example" => "modules clone=software,partitioning"
              }
            },
            "options"  => {
              "clone"    => {
                "type" => "string",
                "help" => _(
                  "Comma separated list of modules to clone. By default, all modules are cloned."
                )
              },
              "filename" => {
                "type" => "string",
                "help" => "filename=OUTPUT_FILE"
              },
              "target"   => {
                "type"     => "enum",
                "typespec" => ["default", "compact"],
                "help"     => _(
                  "How much information to include in the profile. When it is set to 'compact',\n" \
                  "it omits some configuration details in order to reduce the size of the profile."
                )
              }
            },
            "mappings" => { "modules" => ["clone", "filename", "target"] }
          }

          Yast::CommandLine.Run(cmdline)
        end

        nil
      end

      # @return [String] Default filename to write the profile to
      DEFAULT_FILENAME = "/root/autoinst.xml".freeze

      # Clone the system
      #
      # @param options [Hash] Action options
      # @option options [String] filename Path to write the profile to
      # @option options [String] clone Comma separated list of sections to include
      # @option options [String] target How much information to include in the profile
      def clone_system(options)
        filename = options.fetch("filename", DEFAULT_FILENAME)
        target = options.fetch("target", :default).to_sym

        # Autoyast overwriting an already existing config file.
        # The warning is only needed while calling "yast clone_system". It is not
        # needed in the installation workflow where it will be checked by the file selection box
        # directly. (bnc#888546)
        if Yast::Mode.normal && Yast::FileUtils.Exists(filename) && !Yast::Popup.ContinueCancel(_("File %s exists! Really overwrite?") % filename)
          return false
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
            # always clone general
            Yast::ProductControl.clone_modules + ["general"]
          end

        Yast::AutoinstClone.Process(target: target)
        begin
          # The file might contain sensitive data, so let's set the permissions to 0o600.
          ::FileUtils.touch(filename)
          ::FileUtils.chmod(0o600, filename)
          Yast::XML.YCPToXMLFile(:profile, Yast::Profile.current, filename)
        rescue Yast::XMLSerializationError => e
          log.error "Creation of XML failed with #{e.inspect}"
          Yast::Popup.Error(
            _("Could not create the XML file. Please, report a bug.")
          )
        end
        Yast::Popup.ClearFeedback
        true
      end
    end
  end
end
