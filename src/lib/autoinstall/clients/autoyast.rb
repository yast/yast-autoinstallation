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
require "autoinstall/auto_sequence"
require "autoinstall/entries/registry"
require "autoinstall/importer"

Yast.import "Pkg"
Yast.import "Wizard"
Yast.import "Mode"
Yast.import "Profile"
Yast.import "AutoinstConfig"
Yast.import "Popup"
Yast.import "AddOnProduct"
Yast.import "CommandLine"
Yast.import "AutoInstall"
Yast.import "UI"

module Y2Autoinstallation
  module Clients
    # This client is responsible for starting the AutoYaST UI.
    class Autoyast < Yast::Client
      include Yast::Logger

      def initialize
        textdomain "autoinst"

        Yast::Mode.SetMode("autoinst_config")

        Yast.include self, "autoinstall/dialogs.rb"
        Yast.include self, "autoinstall/conftree.rb"
      end

      def main
        registry = Y2Autoinstallation::Entries::Registry.instance
        if registry.groups.empty?
          Yast::Wizard.CreateDialog
          Yast::Popup.Error(_("Error while reading configuration data."))
          Yast::Wizard.CloseDialog
          return :abort
        end

        turn_off_signature_checks

        cmdline = {
          "id"         => "autoyast",
          "help"       => _("AutoYaST"),
          "guihandler" => fun_ref(method(:auto_sequence), "any ()"),
          "actions"    => {
            "ui"           => {
              "handler" => fun_ref(
                method(:run_ui),
                "boolean (map <string, string>)"
              ),
              "help"    => ui_action_help
            },
            "file"         => {
              "handler" => fun_ref(
                method(:run_ui),
                "boolean (map <string, string>)"
              ),
              "help"    => file_action_help
            },
            "module"       => {
              "handler" => fun_ref(
                method(:run_ui),
                "boolean (map <string, string>)"
              ),
              "help"    => module_action_help
            },
            "list-modules" => {
              "handler" => fun_ref(
                method(:list_modules),
                "void ()"
              ),
              "help"    => list_modules_action_help
            }
          },
          "options"    => {
            "filename" => { "type" => "string", "help" => "filename=XML_PROFILE" },
            "modname"  => { "type" => "string", "help" => "modname=AYAST_MODULE" }
          },
          "mappings"   => {
            "ui"     => ["filename", "modname"],
            "file"   => ["filename", "modname"],
            "module" => ["filename", "modname"]
          }
        }

        ret = Yast::CommandLine.Run(cmdline)
        log.debug("ret = #{ret}")

        Yast::AddOnProduct.CleanModeConfigSources

        nil
      end

      # Run the main UI
      #
      # @param options [Hash] Command line options
      # @return true
      def run_ui(options)
        import_profile(options["filename"]) if options["filename"]
        Yast::AutoinstConfig.runModule = options["modname"] || ""
        auto_sequence
        true
      end

      # Displays the list of known modules
      #
      # @param _options [Hash] Command line options
      def list_modules(_options)
        registry = Y2Autoinstallation::Entries::Registry.instance
        items = registry.configurable_descriptions.reduce([]) do |all, description|
          all << Item(description.resource_name, description.name)
        end
        Yast::CommandLine.PrintTable(
          Header(_("Module"), _("Description")),
          items
        )
      end

    private

      # Reads and imports a profile
      #
      # @param filename [String] Profile path
      def import_profile(filename)
        if !Yast::Profile.ReadXML(filename)
          Yast::Popup.Error(
            _(
              "Error while parsing the control file.\n" \
                "Check the log files for more details or fix the\n" \
                "AutoYaST profile and try again.\n"
            )
          )
        end
        Yast::Popup.ShowFeedback(
          _("Reading configuration data"),
          _("This may take a while")
        )
        Y2Autoinstallation::Importer.new(Profile.current).import_sections
        Yast::Popup.ClearFeedback
      end

      # AutoYaST UI sequence
      #
      # @return [Y2Autoinstallation::AutoSequence]
      def auto_sequence
        Y2Autoinstallation::AutoSequence.new.run
      end

      # Turn off signature checks
      #
      # Signature checks are turned off in the UI.
      def turn_off_signature_checks
        Yast::Pkg.CallbackImportGpgKey(
          fun_ref(
            Yast::AutoInstall.method(:callbackTrue_boolean_map_integer),
            "boolean (map <string, any>, integer)"
          )
        )
        Yast::Pkg.CallbackAcceptUnknownGpgKey(
          fun_ref(
            Yast::AutoInstall.method(:callbackTrue_boolean_string_string_integer),
            "boolean (string, string, integer)"
          )
        )
        Yast::Pkg.CallbackAcceptFileWithoutChecksum(
          fun_ref(
            Yast::AutoInstall.method(:callbackTrue_boolean_string),
            "boolean (string)"
          )
        )
        Yast::Pkg.CallbackAcceptUnsignedFile(
          fun_ref(
            Yast::AutoInstall.method(:callbackTrue_boolean_string_integer),
            "boolean (string, integer)"
          )
        )
      end

      # @return [String]
      def file_action_help
        _("File specific operations (deprecated). Use 'ui' action with the 'filename' " \
          "option instead.")
      end

      # @return [String]
      def module_action_help
        _("Module specific operations (deprecated). Use 'ui' action instead with the " \
          "'modname' option instead.")
      end

      # @return [String]
      def ui_action_help
        _("Opens the AutoYaST UI.")
      end

      # @return [String]
      def list_modules_action_help
        _("List known modules.")
      end
    end
  end
end
