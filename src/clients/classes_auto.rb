# encoding: utf-8

# File:  clients/autoinst_linuxrc.ycp
# Package:  Autoinstallation Configuration System
# Summary:   Linuxrc Settings
# Authors:  Anas Nashif<nashif@suse.de>
#
# $Id$
module Yast
  class ClassesAutoClient < Client
    def main
      Yast.import "UI"
      textdomain "autoinst"
      Yast.import "Wizard"
      Yast.import "Summary"
      Yast.import "AutoinstClass"
      Yast.import "AutoinstConfig"

      Yast.import "Label"

      Yast.include self, "autoinstall/dialogs.rb"
      Yast.include self, "autoinstall/classes.rb"

      @ret = nil
      @func = ""
      @param = []

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_list?(WFM.Args(1))
          @param = Convert.to_list(WFM.Args(1))
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Import"
        @ret = AutoinstClass.Import(
          Convert.convert(@param, from: "list", to: "list <map>")
        )
        if @ret.nil?
          Builtins.y2error(
            "Parameter to 'Import' is probably wrong, should be list of maps"
          )
          @ret = false
        end
      # create a  summary
      elsif @func == "Summary"
        @ret = AutoinstClass.Summary
      elsif @func == "Reset"
        AutoinstClass.Import([])
        @ret = []
      elsif @func == "Change"
        Wizard.CreateDialog
        Wizard.SetDesktopIcon("general")
        @ret = classConfiguration
        Wizard.CloseDialog
        return deep_copy(@ret)
      elsif @func == "Export"
        @ret = AutoinstClass.Export
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("General auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)

      # EOF
    end
  end
end

Yast::ClassesAutoClient.new.main
