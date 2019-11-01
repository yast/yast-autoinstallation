# File:  clients/autoyast.ycp
# Summary:  Main file for client call
# Authors:  Anas Nashif <nashif@suse.de>
#
# $Id$
module Yast
  class AutoyastClient < Client
    def main
      Yast.import "Pkg"
      Yast.import "UI"
      textdomain "autoinst"
      Yast.import "Wizard"
      Yast.import "Mode"
      Mode.SetMode("autoinst_config")

      Yast.import "Profile"
      Yast.import "AutoinstConfig"
      Yast.import "Y2ModuleConfig"
      Yast.import "Label"
      Yast.import "Sequencer"
      Yast.import "Popup"
      Yast.import "AddOnProduct"
      Yast.import "CommandLine"
      Yast.import "AutoInstall"

      Yast.include self, "autoinstall/dialogs.rb"
      Yast.include self, "autoinstall/conftree.rb"
      Yast.include self, "autoinstall/wizards.rb"

      if Builtins.size(Y2ModuleConfig.GroupMap) == 0
        Wizard.CreateDialog
        Popup.Error(_("Error while reading configuration data."))
        Wizard.CloseDialog
        return :abort
      end

      Pkg.CallbackImportGpgKey(
        fun_ref(
          AutoInstall.method(:callbackTrue_boolean_map_integer),
          "boolean (map <string, any>, integer)"
        )
      )
      Pkg.CallbackAcceptUnknownGpgKey(
        fun_ref(
          AutoInstall.method(:callbackTrue_boolean_string_string_integer),
          "boolean (string, string, integer)"
        )
      )
      Pkg.CallbackAcceptFileWithoutChecksum(
        fun_ref(
          AutoInstall.method(:callbackTrue_boolean_string),
          "boolean (string)"
        )
      )
      Pkg.CallbackAcceptUnsignedFile(
        fun_ref(
          AutoInstall.method(:callbackTrue_boolean_string_integer),
          "boolean (string, integer)"
        )
      )

      @cmdline = {
        "id"         => "autoyast2",
        "help"       => _("AutoYaST"),
        "guihandler" => fun_ref(method(:AutoSequence), "any ()"),
        "actions"    => {
          "file"   => {
            "handler" => fun_ref(
              method(:openFile),
              "boolean (map <string, string>)"
            ),
            "help"    => "file operations"
          },
          "module" => {
            "handler" => fun_ref(
              method(:runModule),
              "boolean (map <string, string>)"
            ),
            "help"    => "module specific operations"
          }
        },
        "options"    => {
          "filename" => { "type" => "string", "help" => "filename=XML_PROFILE" },
          "modname"  => { "type" => "string", "help" => "modname=AYAST_MODULE" }
        },
        "mappings"   => { "file" => ["filename"], "module" => ["modname"] }
      }

      # command line options
      # Init variables
      @command = ""
      @flags = []
      @options = {}
      @exit = ""
      @l = []

      @ret = nil
      @ret = CommandLine.Run(@cmdline)

      AddOnProduct.CleanModeConfigSources
      :exit
    end

    def openFile(options)
      options = deep_copy(options)
      if !Profile.ReadXML(Ops.get(options, "filename", ""))
        Popup.Error(
          _(
            "Error while parsing the control file.\n" \
              "Check the log files for more details or fix the\n" \
              "control file and try again.\n"
          )
        )
      end
      Popup.ShowFeedback(
        _("Reading configuration data"),
        _("This may take a while")
      )
      Builtins.foreach(Profile.ModuleMap) do |p, d|
        # Set resource name, if not using default value
        resource = Ops.get_string(d, "X-SuSE-YaST-AutoInstResource", "")
        resource = p if resource == ""
        Builtins.y2debug("resource: %1", resource)
        module_auto = Ops.get_string(d, "X-SuSE-YaST-AutoInstClient", "none")
        rd = Y2ModuleConfig.getResourceData(d, resource)
        WFM.CallFunction(module_auto, ["Import", rd]) if !rd.nil?
      end
      Popup.ClearFeedback
      AutoSequence()
      true
    end

    def runModule(options)
      options = deep_copy(options)
      AutoinstConfig.runModule = Ops.get(options, "modname", "")
      AutoSequence()
      true
    end
  end
end

Yast::AutoyastClient.new.main
