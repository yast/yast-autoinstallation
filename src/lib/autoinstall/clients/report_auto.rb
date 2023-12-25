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

require "installation/auto_client"

Yast.import "Label"
Yast.import "Report"
Yast.import "Summary"
Yast.import "Wizard"

module Y2Autoinstallation
  module Clients
    class ReportAuto < ::Installation::AutoClient
      include Yast::I18n

      def initialize
        super
        textdomain "autoinst"
      end

      def import(map)
        Yast::Report.Import(map)
      end

      def summary
        Yast::Report.Summary
      end

      def reset
        Yast::Report.Import({})
      end

      def modified?
        Yast::Report.GetModified
      end

      def modified
        Yast::Report.SetModified
      end

      def export
        Yast::Report.Export
      end

      def change
        Wizard.CreateDialog
        Wizard.SetDesktopIcon("report")
        Wizard.HideAbortButton
        ReportingDialog()
      ensure
        Wizard.CloseDialog
      end

    private

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
          "<p>Depending on your experience, you can skip, log, and show (with time-out)\n" \
          "installation messages.</p> \n"
        )

        help_text = Ops.add(
          help_text,
          _(
            "<p>It is recommended to show all  <b>messages</b> with time-out.\n" \
            "Warnings can be skipped in some places, but should not be ignored.</p>\n"
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
        loop do
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

          break if [:cancel, :next, :back].include?(ret)
        end

        Report.Import(
          "messages"       => msg,
          "errors"         => err,
          "warnings"       => war,
          "yesno_messages" => err
        )
        ret
      end
    end
  end
end
