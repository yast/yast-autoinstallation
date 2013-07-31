# encoding: utf-8

# File:	clients/autoinst_report.ycp
# Package:	Autoinstallation Configuration System
# Summary:	Report
# Authors:	Anas Nashif<nashif@suse.de>
#
# $Id$
module Yast
  class ReportAutoClient < Client
    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.import "Wizard"
      Yast.import "Summary"
      Yast.import "Report"

      Yast.import "Label"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Report auto started")

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



      # Create a summary
      # return string
      if @func == "Import"
        @ret = Report.Import(@param)
      # Create a summary
      # return string
      elsif @func == "Summary"
        @ret = Report.Summary
      # Reset configuration
      # return map or list
      elsif @func == "Reset"
        Report.Import({})
        @ret = {}
      # Change configuration
      # return symbol (i.e. `finish || `accept || `next || `cancel || `abort)
      elsif @func == "Change"
        Wizard.CreateDialog
        Wizard.SetDesktopIcon("report")
        Wizard.HideAbortButton
        @ret = ReportingDialog()
        Wizard.CloseDialog
      # Return configuration data
      # return map or list
      elsif @func == "Export"
        @ret = Report.Export
      elsif @func == "GetModified"
        @ret = Report.GetModified
      elsif @func == "SetModified"
        Report.SetModified
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("Report auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end

    # ReportingDialog()
    # @return sumbol
    def ReportingDialog
      msg = deep_copy(Report.message_settings)
      err = deep_copy(Report.error_settings)
      war = deep_copy(Report.warning_settings)


      contents = Top(
        VBox(
          VSpacing(2),
          VSquash(
            VBox(
              Frame(
                _("Messages"),
                HBox(
                  HWeight(
                    35,
                    CheckBox(
                      Id(:msgshow),
                      _("Sho&w messages"),
                      Ops.get_boolean(msg, "show", true)
                    )
                  ),
                  HWeight(
                    35,
                    CheckBox(
                      Id(:msglog),
                      _("Lo&g messages"),
                      Ops.get_boolean(msg, "log", true)
                    )
                  ),
                  HWeight(
                    30,
                    VBox(
                      VSpacing(),
                      Bottom(
                        IntField(
                          Id(:msgtime),
                          _("&Time-out (in sec.)"),
                          0,
                          100,
                          Ops.get_integer(msg, "timeout", 10)
                        )
                      )
                    )
                  )
                )
              ),
              VSpacing(1),
              Frame(
                _("Warnings"),
                HBox(
                  HWeight(
                    35,
                    CheckBox(
                      Id(:warshow),
                      _("Sh&ow warnings"),
                      Ops.get_boolean(war, "show", true)
                    )
                  ),
                  HWeight(
                    35,
                    CheckBox(
                      Id(:warlog),
                      _("Log wa&rnings"),
                      Ops.get_boolean(war, "log", true)
                    )
                  ),
                  HWeight(
                    30,
                    VBox(
                      VSpacing(),
                      Bottom(
                        IntField(
                          Id(:wartime),
                          _("Time-out (in s&ec.)"),
                          0,
                          100,
                          Ops.get_integer(war, "timeout", 10)
                        )
                      )
                    )
                  )
                )
              ),
              VSpacing(1),
              Frame(
                _("Errors"),
                HBox(
                  HWeight(
                    35,
                    CheckBox(
                      Id(:errshow),
                      _("Show error&s"),
                      Ops.get_boolean(err, "show", true)
                    )
                  ),
                  HWeight(
                    35,
                    CheckBox(
                      Id(:errlog),
                      _("&Log errors"),
                      Ops.get_boolean(err, "log", true)
                    )
                  ),
                  HWeight(
                    30,
                    VBox(
                      VSpacing(),
                      Bottom(
                        IntField(
                          Id(:errtime),
                          _("Time-o&ut (in sec.)"),
                          0,
                          100,
                          Ops.get_integer(err, "timeout", 10)
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )

      help_text = _(
        "<p>Depending on your experience, you can skip, log, and show (with time-out)\ninstallation messages.</p> \n"
      )

      help_text = Ops.add(
        help_text,
        _(
          "<p>It is recommended to show all  <b>messages</b> with time-out.\nWarnings can be skipped in some places, but should not be ignored.</p>\n"
        )
      )

      Wizard.SetNextButton(:next, Label.FinishButton)
      Wizard.SetContents(
        _("Messages and Logging"),
        contents,
        help_text,
        true,
        true
      )

      ret = :none
      begin
        ret = Convert.to_symbol(UI.UserInput)
        if ret == :next
          Ops.set(
            msg,
            "show",
            Convert.to_boolean(UI.QueryWidget(Id(:msgshow), :Value))
          )
          Ops.set(
            msg,
            "log",
            Convert.to_boolean(UI.QueryWidget(Id(:msglog), :Value))
          )
          Ops.set(
            msg,
            "timeout",
            Convert.to_integer(UI.QueryWidget(Id(:msgtime), :Value))
          )
          Ops.set(
            err,
            "show",
            Convert.to_boolean(UI.QueryWidget(Id(:errshow), :Value))
          )
          Ops.set(
            err,
            "log",
            Convert.to_boolean(UI.QueryWidget(Id(:errlog), :Value))
          )
          Ops.set(
            err,
            "timeout",
            Convert.to_integer(UI.QueryWidget(Id(:errtime), :Value))
          )
          Ops.set(
            war,
            "show",
            Convert.to_boolean(UI.QueryWidget(Id(:warshow), :Value))
          )
          Ops.set(
            war,
            "log",
            Convert.to_boolean(UI.QueryWidget(Id(:warlog), :Value))
          )
          Ops.set(
            war,
            "timeout",
            Convert.to_integer(UI.QueryWidget(Id(:wartime), :Value))
          )
        end
      end until ret == :cancel || ret == :next || ret == :back

      Report.Import(
        {
          "messages"       => msg,
          "errors"         => err,
          "warnings"       => war,
          "yesno_messages" => err
        }
      )
      ret
    end
  end
end

Yast::ReportAutoClient.new.main
