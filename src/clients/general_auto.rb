# encoding: utf-8

# File:  clients/autoinst_general.ycp
# Package:  Autoinstallation Configuration System
# Summary:  General Settings
# Authors:  Anas Nashif<nashif@suse.de>
#
# $Id$
module Yast
  class GeneralAutoClient < Client
    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.import "AutoinstGeneral"
      Yast.import "Wizard"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Sequencer"

      Yast.include self, "autoinstall/general_dialogs.rb"

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
        @ret = AutoinstGeneral.Import(@param)
      # create a  summary
      elsif @func == "Summary"
        @ret = AutoinstGeneral.Summary
      elsif @func == "GetModified"
        @ret = AutoinstGeneral.GetModified
      elsif @func == "SetModified"
        AutoinstGeneral.SetModified
      elsif @func == "Reset"
        AutoinstGeneral.Import({})
        @ret = {}
      elsif @func == "Change"
        @ret = generalSequence
        return deep_copy(@ret)
      elsif @func == "Export"
        @ret = AutoinstGeneral.Export
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

Yast::GeneralAutoClient.new.main
