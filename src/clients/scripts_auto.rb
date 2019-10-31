# File:  clients/autoinst_scripts.ycp
# Package:  Autoinstallation Configuration System
# Summary:  Scripts
# Authors:  Anas Nashif<nashif@suse.de>
#
# $Id$
module Yast
  class ScriptsAutoClient < Client
    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.import "AutoinstScripts"
      Yast.import "Wizard"
      Yast.import "Summary"

      Yast.import "Label"
      Yast.import "Popup"

      Yast.include self, "autoinstall/script_dialogs.rb"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end

      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Import"
        @ret = AutoinstScripts.Import(@param)
      # create a  summary
      elsif @func == "Summary"
        @ret = AutoinstScripts.Summary
      elsif @func == "Reset"
        AutoinstScripts.Import({})
        @ret = {}
      elsif @func == "GetModified"
        @ret = AutoinstScripts.GetModified
      elsif @func == "SetModified"
        AutoinstScripts.SetModified
      elsif @func == "Change"
        Wizard.CreateDialog
        Wizard.SetDesktopIcon("org.opensuse.yast.AutoYaST")
        @ret = ScriptsDialog()
        Wizard.CloseDialog
      elsif @func == "Export"
        @ret = AutoinstScripts.Export
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("scripts auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)
    end
  end
end

Yast::ScriptsAutoClient.new.main
