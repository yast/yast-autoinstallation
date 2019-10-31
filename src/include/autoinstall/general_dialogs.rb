# encoding: utf-8

# File:  clients/autoinst_general.ycp
# Package:  Autoinstallation Configuration System
# Summary:  General Settings
# Authors:  Anas Nashif<nashif@suse.de>
#
# $Id$
module Yast
  module AutoinstallGeneralDialogsInclude
    def initialize_autoinstall_general_dialogs(_include_target)
      textdomain "autoinst"
      Yast.import "GetInstArgs"
      Yast.import "Label"
    end

    # Main dialog
    # @return [Symbol]
    def ModeDialog
      mode = deep_copy(AutoinstGeneral.mode)
      signature_handling = deep_copy(AutoinstGeneral.signature_handling)
      confirm = Ops.get_boolean(mode, "confirm", true)
      second_stage = Ops.get_boolean(mode, "second_stage", true)
      halt = Ops.get_boolean(mode, "halt", false)
      halt_second = Ops.get_boolean(mode, "final_halt", false)
      reboot_second = Ops.get_boolean(mode, "final_reboot", false)

      accept_unsigned_file = Ops.get_boolean(
        signature_handling,
        "accept_unsigned_file",
        false
      )
      accept_file_without_checksum = Ops.get_boolean(
        signature_handling,
        "accept_file_without_checksum",
        false
      )
      accept_verification_failed = Ops.get_boolean(
        signature_handling,
        "accept_verification_failed",
        false
      )
      accept_unknown_gpg_key = Ops.get_boolean(
        signature_handling,
        "accept_unknown_gpg_key",
        false
      )
      import_gpg_key = Ops.get_boolean(
        signature_handling,
        "import_gpg_key",
        false
      )
      accept_non_trusted_gpg_key = Ops.get_boolean(
        signature_handling,
        "accept_non_trusted_gpg_key",
        false
      )

      contents = HVSquash(
        VBox(
          Left(CheckBox(Id(:confirm), _("Con&firm installation?"), confirm)),
          Left(
            CheckBox(
              Id(:second_stage),
              _("AutoYaST Second Stage"),
              second_stage
            )
          ),
          Left(
            CheckBox(
              Id(:halt),
              _("Turn Off the Machine after the First Stage"),
              halt
            )
          ),
          Left(
            CheckBox(
              Id(:halt_second),
              _("Turn off the Machine after the Second Stage"),
              halt_second
            )
          ),
          Left(
            CheckBox(
              Id(:reboot_second),
              _("Reboot the Machine after the Second Stage"),
              reboot_second
            )
          ),
          Left(Label(_("Signature Handling"))),
          Left(
            CheckBox(
              Id(:accept_unsigned_file),
              _("Accept &Unsigned Files"),
              accept_unsigned_file
            )
          ),
          Left(
            CheckBox(
              Id(:accept_file_without_checksum),
              _("Accept Files without a &Checksum"),
              accept_file_without_checksum
            )
          ),
          Left(
            CheckBox(
              Id(:accept_verification_failed),
              _("Accept Failed &Verifications"),
              accept_verification_failed
            )
          ),
          Left(
            CheckBox(
              Id(:accept_unknown_gpg_key),
              _("Accept Unknown &GPG Keys"),
              accept_unknown_gpg_key
            )
          ),
          Left(
            CheckBox(
              Id(:accept_non_trusted_gpg_key),
              _("Accept Non Trusted GPG Keys"),
              accept_non_trusted_gpg_key
            )
          ),
          Left(
            CheckBox(
              Id(:import_gpg_key),
              _("Import &New GPG Keys"),
              import_gpg_key
            )
          )
        )
      )

      help_text = _(
        "<P>\n" \
          "The options in this dialog control the behavior of the AutoYaST during\n" \
          "automatic installation.\n" \
          "</P>\n"
      )
      help_text = Ops.add(
        help_text,
        _(
          "<P>\n" \
            "The installation confirmation option is selected by default\n" \
            "to avoid unwanted installation. It stops the system\n" \
            "during installation and shows a summary of requested operations in the\n" \
            "usual proposal screen.  Uncheck this option to install " \
            "automatically without interruption.\n" \
            "</P>\n"
        )
      )
      help_text = Ops.add(
        help_text,
        _(
          "<P>\n" \
            "If you turn off the second stage of AutoYaST, the " \
            "installation continues in manual mode\n" \
            "after the first reboot (after package installation).\n" \
            "</P>\n"
        )
      )

      help_text = Ops.add(
        help_text,
        _(
          "<P>\n" \
            "For signature handling, read the AutoYaST documentation.\n" \
            "</P>\n"
        )
      )

      Wizard.SetContents(_("Other Options"), contents, help_text, true, true)

      Wizard.HideAbortButton
      Wizard.SetNextButton(:next, Label.NextButton)

      ret = nil
      begin
        ret = UI.UserInput
        if ret == :next
          confirm = Convert.to_boolean(UI.QueryWidget(Id(:confirm), :Value))
          second_stage = Convert.to_boolean(
            UI.QueryWidget(Id(:second_stage), :Value)
          )
          halt = Convert.to_boolean(UI.QueryWidget(Id(:halt), :Value))
          halt_second = Convert.to_boolean(
            UI.QueryWidget(Id(:halt_second), :Value)
          )
          reboot_second = Convert.to_boolean(
            UI.QueryWidget(Id(:reboot_second), :Value)
          )

          Ops.set(mode, "second_stage", second_stage)
          Ops.set(mode, "confirm", confirm)
          Ops.set(mode, "halt", halt)
          Ops.set(mode, "final_halt", halt_second)
          Ops.set(mode, "final_reboot", reboot_second)
          AutoinstGeneral.mode = deep_copy(mode)

          Ops.set(
            signature_handling,
            "accept_unsigned_file",
            Convert.to_boolean(
              UI.QueryWidget(Id(:accept_unsigned_file), :Value)
            )
          )
          Ops.set(
            signature_handling,
            "accept_file_without_checksum",
            Convert.to_boolean(
              UI.QueryWidget(Id(:accept_file_without_checksum), :Value)
            )
          )
          Ops.set(
            signature_handling,
            "accept_verification_failed",
            Convert.to_boolean(
              UI.QueryWidget(Id(:accept_verification_failed), :Value)
            )
          )
          Ops.set(
            signature_handling,
            "accept_unknown_gpg_key",
            Convert.to_boolean(
              UI.QueryWidget(Id(:accept_unknown_gpg_key), :Value)
            )
          )
          Ops.set(
            signature_handling,
            "import_gpg_key",
            Convert.to_boolean(UI.QueryWidget(Id(:import_gpg_key), :Value))
          )
          Ops.set(
            signature_handling,
            "accept_non_trusted_gpg_key",
            Convert.to_boolean(
              UI.QueryWidget(Id(:accept_non_trusted_gpg_key), :Value)
            )
          )
          AutoinstGeneral.signature_handling = deep_copy(signature_handling)
        end
      end until ret == :next || ret == :back || ret == :cancel
      Convert.to_symbol(ret)
    end

    def newQuestion(stage, dialog, askList, title, defaultValues)
      askList = deep_copy(askList)
      defaultValues = deep_copy(defaultValues)
      ret = :x
      selection = []
      selId = 0
      if Ops.greater_than(
        Builtins.size(Ops.get_list(defaultValues, "selection", [])),
        0
      )
        Builtins.foreach(Ops.get_list(defaultValues, "selection", [])) do |m|
          selection = Builtins.add(
            selection,
            Item(
              Id(selId),
              Ops.get_string(m, "label", ""),
              Ops.get_string(m, "value", "")
            )
          )
          selId = Ops.add(selId, 1)
        end
      end
      selId = 0

      contents = HVSquash(
        VBox(
          TextEntry(
            Id(:frametitle),
            _("Frametitle"),
            Ops.get_string(defaultValues, "frametitle", "")
          ),
          TextEntry(
            Id(:question),
            _("Question"),
            Ops.get_string(defaultValues, "question", "")
          ),
          IntField(
            Id(:timeout),
            _("Timeout (zero means no timeout)"),
            0,
            999,
            Ops.get_integer(defaultValues, "timeout", 0)
          ),
          TextEntry(
            Id(:defaultVal),
            "Default",
            Ops.get_string(defaultValues, "default", "")
          ),
          Left(
            RadioButtonGroup(
              Id(:type),
              HBox(
                RadioButton(
                  Id(:t_text),
                  Opt(:notify, :immediate),
                  "Text",
                  Ops.get_string(defaultValues, "type", "text") == "text"
                ),
                RadioButton(
                  Id(:t_symbol),
                  Opt(:notify, :immediate),
                  "Symbol",
                  Ops.get_string(defaultValues, "type", "text") == "symbol"
                ),
                RadioButton(
                  Id(:t_boolean),
                  Opt(:notify, :immediate),
                  "Boolean",
                  Ops.get_string(defaultValues, "type", "text") == "boolean"
                ),
                RadioButton(
                  Id(:t_integer),
                  Opt(:notify, :immediate),
                  "Integer",
                  Ops.get_string(defaultValues, "type", "text") == "integer"
                ),
                CheckBox(
                  Id(:password),
                  _("Password"),
                  Ops.get_boolean(defaultValues, "password", false)
                )
              )
            )
          ),
          TextEntry(
            Id(:path),
            _("Pathlist for answers (multiple paths are separated by space)"),
            Builtins.mergestring(
              Ops.get_list(defaultValues, "pathlist", []),
              " "
            )
          ),
          TextEntry(
            Id(:file),
            _("Store answer in this file"),
            Ops.get_string(defaultValues, "file", "")
          ),
          Label(_("Selection List for type 'Symbol'")),
          HBox(
            MinSize(
              10,
              5,
              Table(Id(:selection), Header(_("Label"), _("Value")), selection)
            ),
            VBox(
              PushButton(
                Id(:delSelection),
                Opt(:default, :hstretch),
                Label.DeleteButton
              )
            )
          ),
          HBox(
            TextEntry(Id(:selLabel), Opt(:notify, :immediate), _("Label"), ""),
            TextEntry(Id(:selValue), Opt(:notify, :immediate), _("Value"), ""),
            PushButton(
              Id(:addSelection),
              Opt(:default, :hstretch),
              Label.AddButton
            )
          ),
          HBox(
            PushButton(Id(:ok), Opt(:default, :hstretch), Label.OKButton),
            PushButton(Id(:abort), Opt(:default, :hstretch), Label.AbortButton)
          )
        )
      )
      UI.OpenDialog(Opt(:decorated), contents)
      UI.ChangeWidget(Id(:selLabel), :Enabled, false)
      UI.ChangeWidget(Id(:selValue), :Enabled, false)
      UI.ChangeWidget(Id(:selection), :Enabled, false)
      UI.ChangeWidget(Id(:password), :Enabled, false)

      if Ops.get_string(defaultValues, "type", "text") == "text"
        UI.ChangeWidget(Id(:password), :Enabled, true)
      elsif Ops.get_string(defaultValues, "type", "text") == "symbol"
        UI.ChangeWidget(Id(:selLabel), :Enabled, true)
        UI.ChangeWidget(Id(:selValue), :Enabled, true)
        UI.ChangeWidget(Id(:selection), :Enabled, true)
      end
      begin
        if Builtins.size(
          Convert.to_list(UI.QueryWidget(Id(:selection), :Items))
        ) == 0
          UI.ChangeWidget(Id(:delSelection), :Enabled, false)
        else
          UI.ChangeWidget(Id(:delSelection), :Enabled, true)
        end
        if Builtins.size(
          Convert.to_string(UI.QueryWidget(Id(:selLabel), :Value))
        ) == 0 ||
            Builtins.size(
              Convert.to_string(UI.QueryWidget(Id(:selValue), :Value))
            ) == 0
          UI.ChangeWidget(Id(:addSelection), :Enabled, false)
        else
          UI.ChangeWidget(Id(:addSelection), :Enabled, true)
        end
        ret = Convert.to_symbol(UI.UserInput)
        if ret == :addSelection
          label = Convert.to_string(UI.QueryWidget(Id(:selLabel), :Value))
          val = Convert.to_string(UI.QueryWidget(Id(:selValue), :Value))
          selection = Builtins.add(selection, Item(Id(selId), label, val))
          selId = Ops.add(selId, 1)
          UI.ChangeWidget(Id(:selection), :Items, selection)
        elsif ret == :t_symbol
          UI.ChangeWidget(Id(:selLabel), :Enabled, true)
          UI.ChangeWidget(Id(:selValue), :Enabled, true)
          UI.ChangeWidget(Id(:selection), :Enabled, true)
          UI.ChangeWidget(Id(:password), :Enabled, false)
        elsif ret == :t_text
          UI.ChangeWidget(Id(:selLabel), :Enabled, false)
          UI.ChangeWidget(Id(:selValue), :Enabled, false)
          UI.ChangeWidget(Id(:selection), :Enabled, false)
          UI.ChangeWidget(Id(:password), :Enabled, true)
        elsif ret == :t_boolean || ret == :t_integer
          UI.ChangeWidget(Id(:selLabel), :Enabled, false)
          UI.ChangeWidget(Id(:selValue), :Enabled, false)
          UI.ChangeWidget(Id(:selection), :Enabled, false)
          UI.ChangeWidget(Id(:password), :Enabled, false)
        elsif ret == :delSelection
          currSelId = Convert.to_integer(
            UI.QueryWidget(Id(:selection), :CurrentItem)
          )
          selection = Builtins.filter(selection) do |s|
            l = Builtins.argsof(s)
            Ops.get_term(l, 0) { Id(-1) } != Id(currSelId)
          end
          UI.ChangeWidget(Id(:selection), :Items, selection)
        elsif ret == :ok
          max = -1
          Builtins.foreach(askList) do |m|
            if Ops.get_string(m, "stage", "initial") == stage &&
                Ops.get_integer(m, "dialog", 0) == dialog &&
                Ops.greater_than(Ops.get_integer(m, "element", -1), max)
              max = Ops.get_integer(m, "element", -1)
            end
          end
          max = Ops.add(max, 1)
          newVal = {
            "default"  => Convert.to_string(
              UI.QueryWidget(Id(:defaultVal), :Value)
            ),
            "title"    => title,
            "stage"    => stage,
            "dialog"   => dialog,
            "element"  => Ops.get_integer(defaultValues, "element", max),
            "script"   => Ops.get_map(defaultValues, "script", {}),
            "question" => Convert.to_string(
              UI.QueryWidget(Id(:question), :Value)
            )
          }
          if Convert.to_string(UI.QueryWidget(Id(:frametitle), :Value)) != ""
            Ops.set(
              newVal,
              "frametitle",
              Convert.to_string(UI.QueryWidget(Id(:frametitle), :Value))
            )
          end
          if Convert.to_integer(UI.QueryWidget(Id(:timeout), :Value)) != 0
            Ops.set(
              newVal,
              "timeout",
              Convert.to_integer(UI.QueryWidget(Id(:timeout), :Value))
            )
          end
          if Convert.to_symbol(UI.QueryWidget(Id(:type), :CurrentButton)) == :t_symbol
            Ops.set(newVal, "type", "symbol")
          elsif Convert.to_symbol(UI.QueryWidget(Id(:type), :CurrentButton)) == :t_boolean
            Ops.set(newVal, "type", "boolean")
          elsif Convert.to_symbol(UI.QueryWidget(Id(:type), :CurrentButton)) == :t_integer
            Ops.set(newVal, "type", "integer")
          end
          if Convert.to_string(UI.QueryWidget(Id(:path), :Value)) != ""
            Ops.set(
              newVal,
              "pathlist",
              Builtins.splitstring(
                Convert.to_string(UI.QueryWidget(Id(:path), :Value)),
                " "
              )
            )
          end
          if Convert.to_string(UI.QueryWidget(Id(:file), :Value)) != ""
            Ops.set(
              newVal,
              "file",
              Convert.to_string(UI.QueryWidget(Id(:file), :Value))
            )
          end
          if Convert.to_symbol(UI.QueryWidget(Id(:type), :CurrentButton)) == :t_text
            Ops.set(
              newVal,
              "password",
              Convert.to_boolean(UI.QueryWidget(Id(:password), :Value))
            )
          end
          if Ops.greater_than(Builtins.size(selection), 0)
            r = []
            Builtins.foreach(selection) do |t|
              l = Builtins.argsof(t)
              r = Builtins.add(
                r,
                "label" => Ops.get_string(l, 1, ""),
                "value" => Ops.get_string(l, 2, "")
              )
            end
            Ops.set(newVal, "selection", r)
          end
          askList = if Builtins.size(defaultValues) == 0
            Builtins.add(askList, newVal)
          else
            Builtins.maplist(askList) do |d|
              if Ops.get_string(d, "stage", "initial") == stage &&
                  Ops.get_integer(d, "dialog", -1) == dialog &&
                  Ops.get_integer(d, "element", -1) ==
                      Ops.get_integer(defaultValues, "element", -1)
                d = deep_copy(newVal)
              end
              deep_copy(d)
            end
          end
        end
      end until ret == :abort || ret == :ok
      UI.CloseDialog

      deep_copy(askList)
    end

    def askDialog
      askList = Convert.convert(
        AutoinstGeneral.askList,
        from: "list",
        to:   "list <map>"
      )
      title = ""
      help = ""
      dialogs = []
      questions = []
      elementCount = {}

      id_counter = 0
      askList = Builtins.maplist(askList) do |dialog|
        id_counter = Ops.get_integer(dialog, "dialog", id_counter)
        Ops.set(dialog, "dialog", id_counter)
        Ops.set(elementCount, id_counter, 0) if !Builtins.haskey(elementCount, id_counter)
        Ops.set(
          dialog,
          "element",
          Ops.get_integer(
            dialog,
            "element",
            Ops.get(elementCount, id_counter, -1)
          )
        )
        Ops.set(
          elementCount,
          id_counter,
          Ops.add(Ops.get(elementCount, id_counter, -1), 1)
        )
        id_counter = Ops.add(id_counter, 1)
        deep_copy(dialog)
      end
      askList = Builtins.sort(askList) do |x, y|
        Ops.less_than(
          Ops.get_integer(x, "dialog", -2),
          Ops.get_integer(y, "dialog", -1)
        ) ||
          Ops.get_integer(x, "dialog", -2) == Ops.get_integer(y, "dialog", -1) &&
            Ops.less_than(
              Ops.get_integer(x, "element", -2),
              Ops.get_integer(y, "element", -1)
            )
      end
      done = { "initial" => [] }
      Builtins.foreach(askList) do |m|
        if Ops.get_string(m, "stage", "initial") == "initial" &&
            !Builtins.contains(
              Ops.get(done, "initial", []),
              Ops.get_integer(m, "dialog", -1)
            )
          dialogs = Builtins.add(
            dialogs,
            Item(
              Id(Ops.get_integer(m, "dialog", -1)),
              Ops.get_string(m, "title", "")
            )
          )
          if title == ""
            title = Ops.get_string(m, "title", "")
            help = Ops.get_string(m, "help", "")
          end
          Ops.set(
            done,
            "initial",
            Builtins.add(
              Ops.get(done, "initial", []),
              Ops.get_integer(m, "dialog", -1)
            )
          )
        end
      end
      d = Builtins.filter(askList) do |dummy|
        Ops.get_integer(dummy, "dialog", -2) ==
          Ops.get_integer(askList, [0, "dialog"], 0) &&
          "initial" == Ops.get_string(dummy, "stage", "initital")
      end
      Builtins.foreach(d) do |m|
        id_counter = Ops.get_integer(m, "element", id_counter)
        questions = Builtins.add(
          questions,
          Item(Id(id_counter), Ops.get_string(m, "question", ""))
        )
        id_counter = Ops.add(id_counter, 1)
      end
      contents = HVSquash(
        VBox(
          RadioButtonGroup(
            Id(:stage),
            HBox(
              RadioButton(
                Id(:stage_initial),
                Opt(:notify, :immediate),
                _("1st Stage"),
                true
              ),
              RadioButton(
                Id(:stage_cont),
                Opt(:notify, :immediate),
                _("2nd Stage")
              )
            )
          ),
          TextEntry(Id(:dialogTitle), _("Dialog Title"), title),
          MultiLineEdit(Id(:hlp), _("Helptext"), help),
          HBox(
            PushButton(
              Id(:addDialog),
              Opt(:default, :hstretch),
              _("Add to Dialog List")
            ),
            PushButton(
              Id(:applyDialog),
              Opt(:default, :hstretch),
              _("Apply changes to dialog")
            )
          ),
          MinSize(
            10,
            5,
            SelectionBox(
              Id(:dialogs),
              Opt(:notify, :immediate),
              _("Title"),
              dialogs
            )
          ),
          HBox(
            PushButton(
              Id(:deleteDialog),
              Opt(:default, :hstretch),
              _("Delete Dialog")
            ),
            PushButton(Id(:dialogUp), Opt(:default, :hstretch), _("Dialog up")),
            PushButton(
              Id(:dialogDown),
              Opt(:default, :hstretch),
              _("Dialog down")
            )
          ),
          Label(_("Questions in dialog")),
          MinSize(10, 5, SelectionBox(Id(:questions), _("Question"), questions)),
          HBox(
            PushButton(
              Id(:addQuestion),
              Opt(:default, :hstretch),
              _("Add Question")
            ),
            PushButton(
              Id(:editQuestion),
              Opt(:default, :hstretch),
              _("Edit Question")
            ),
            PushButton(
              Id(:deleteQuestion),
              Opt(:default, :hstretch),
              _("Delete Question")
            ),
            PushButton(
              Id(:questionUp),
              Opt(:default, :hstretch),
              _("Question up")
            ),
            PushButton(
              Id(:questionDown),
              Opt(:default, :hstretch),
              _("Question down")
            )
          )
        )
      )
      help_text = _("<P></P>")
      Wizard.SetContents(_("ASK Options"), contents, help_text, true, true)

      Wizard.HideAbortButton
      Wizard.SetNextButton(:next, Label.FinishButton)

      ret = nil
      dialog_id = -1
      element_id = -1
      begin
        if Builtins.size(Convert.to_list(UI.QueryWidget(Id(:dialogs), :Items))) == 0
          UI.ChangeWidget(Id(:addQuestion), :Enabled, false)
          UI.ChangeWidget(Id(:editQuestion), :Enabled, false)
          UI.ChangeWidget(Id(:questionUp), :Enabled, false)
          UI.ChangeWidget(Id(:deleteDialog), :Enabled, false)
        else
          UI.ChangeWidget(Id(:addQuestion), :Enabled, true)
          UI.ChangeWidget(Id(:editQuestion), :Enabled, true)
          UI.ChangeWidget(Id(:deleteDialog), :Enabled, true)
        end
        if Ops.greater_than(
          Builtins.size(
            Convert.to_list(UI.QueryWidget(Id(:questions), :Items))
          ),
          1
        )
          UI.ChangeWidget(Id(:questionUp), :Enabled, true)
          UI.ChangeWidget(Id(:questionDown), :Enabled, true)
          UI.ChangeWidget(Id(:deleteQuestion), :Enabled, true)
        else
          UI.ChangeWidget(Id(:questionUp), :Enabled, false)
          UI.ChangeWidget(Id(:questionDown), :Enabled, false)
          UI.ChangeWidget(Id(:deleteQuestion), :Enabled, false)
        end
        if Ops.greater_than(
          Builtins.size(Convert.to_list(UI.QueryWidget(Id(:dialogs), :Items))),
          1
        )
          UI.ChangeWidget(Id(:dialogUp), :Enabled, true)
          UI.ChangeWidget(Id(:dialogDown), :Enabled, true)
        else
          UI.ChangeWidget(Id(:dialogUp), :Enabled, false)
          UI.ChangeWidget(Id(:dialogDown), :Enabled, false)
        end

        ret = UI.UserInput
        stage = "initial"
        if Convert.to_symbol(UI.QueryWidget(Id(:stage), :CurrentButton)) == :stage_cont
          stage = "cont"
        end
        id_counter2 = 0
        dialogs = []
        askList = Builtins.maplist(askList) do |dialog|
          id_counter2 = Ops.get_integer(dialog, "dialog", id_counter2)
          if Ops.get_string(dialog, "stage", "initial") == stage
            dialogs = Builtins.add(
              dialogs,
              Item(Id(id_counter2), Ops.get_string(dialog, "title", ""))
            )
          end
          deep_copy(dialog)
        end
        if ret == :addQuestion
          l = Builtins.argsof(
            Ops.get(
              dialogs,
              Convert.to_integer(UI.QueryWidget(Id(:dialogs), :CurrentItem)),
              term(:empty)
            )
          )
          askList = newQuestion(
            stage,
            Convert.to_integer(UI.QueryWidget(Id(:dialogs), :CurrentItem)),
            askList,
            Ops.get_string(l, 1, ""),
            {}
          )
        elsif ret == :editQuestion
          m = {}
          Builtins.foreach(askList) do |dummy|
            if Ops.get_integer(dummy, "dialog", -1) ==
                Convert.to_integer(UI.QueryWidget(Id(:dialogs), :CurrentItem)) &&
                Ops.get_integer(dummy, "element", -2) ==
                    Convert.to_integer(
                      UI.QueryWidget(Id(:questions), :CurrentItem)
                    )
              m = deep_copy(dummy)
            end
          end
          l = Builtins.argsof(
            Ops.get(
              dialogs,
              Convert.to_integer(UI.QueryWidget(Id(:dialogs), :CurrentItem)),
              term(:empty)
            )
          )
          askList = newQuestion(
            stage,
            Convert.to_integer(UI.QueryWidget(Id(:dialogs), :CurrentItem)),
            askList,
            Ops.get_string(l, 1, ""),
            m
          )
        elsif ret == :deleteQuestion
          dialog_id = Convert.to_integer(
            UI.QueryWidget(Id(:dialogs), :CurrentItem)
          )
          element_id = Convert.to_integer(
            UI.QueryWidget(Id(:questions), :CurrentItem)
          )
          askList = Builtins.filter(askList) do |dialog|
            !(Ops.get_integer(dialog, "dialog", -1) == dialog_id &&
              Ops.get_integer(dialog, "element", -1) == element_id)
          end
        elsif ret == :deleteDialog
          dialog_id = Convert.to_integer(
            UI.QueryWidget(Id(:dialogs), :CurrentItem)
          )
          askList = Builtins.filter(askList) do |dialog|
            Ops.get_integer(dialog, "dialog", -1) != dialog_id
          end
        elsif ret == :applyDialog
          askList = Builtins.maplist(askList) do |d3|
            if Ops.get_integer(d3, "dialog", -1) ==
                Convert.to_integer(UI.QueryWidget(Id(:dialogs), :CurrentItem)) &&
                Ops.get_string(d3, "stage", "initial") == stage
              Ops.set(
                d3,
                "help",
                Convert.to_string(UI.QueryWidget(Id(:hlp), :Value))
              )
              Ops.set(
                d3,
                "title",
                Convert.to_string(UI.QueryWidget(Id(:dialogTitle), :Value))
              )
              help = Ops.get_string(d3, "help", "")
            end
            deep_copy(d3)
          end
        elsif ret == :dialogUp
          dialog_id = Convert.to_integer(
            UI.QueryWidget(Id(:dialogs), :CurrentItem)
          )
          upperDialog = -10
          Builtins.foreach(askList) do |dialog|
            if Ops.get_integer(dialog, "dialog", -2) == dialog_id &&
                Ops.get_string(dialog, "stage", "initial") == stage
              raise Break
            end

            if Ops.get_string(dialog, "stage", "initial") == stage
              upperDialog = Ops.get_integer(dialog, "dialog", -2)
            end
          end
          askList = Builtins.maplist(askList) do |dialog|
            if upperDialog != -10 &&
                Ops.get_integer(dialog, "dialog", -1) == dialog_id &&
                Ops.get_string(dialog, "stage", "initial") == stage
              Ops.set(dialog, "dialog", upperDialog)
            elsif Ops.get_integer(dialog, "dialog", -1) == upperDialog &&
                Ops.get_string(dialog, "stage", "initial") == stage
              Ops.set(dialog, "dialog", dialog_id)
            end
            deep_copy(dialog)
          end
          UI.ChangeWidget(Id(:dialogs), :CurrentItem, upperDialog)
        elsif ret == :dialogDown
          dialog_id = Convert.to_integer(
            UI.QueryWidget(Id(:dialogs), :CurrentItem)
          )
          lowerDialog = -10
          found = false
          Builtins.foreach(askList) do |dialog|
            if found && Ops.get_string(dialog, "stage", "initial") == stage
              lowerDialog = Ops.get_integer(dialog, "dialog", -2)
              raise Break
            end
            found = true if Ops.get_integer(dialog, "dialog", -2) == dialog_id
          end
          askList = Builtins.maplist(askList) do |dialog|
            if lowerDialog != -10 &&
                Ops.get_integer(dialog, "dialog", -1) == dialog_id &&
                Ops.get_string(dialog, "stage", "initial") == stage
              Ops.set(dialog, "dialog", lowerDialog)
            elsif Ops.get_integer(dialog, "dialog", -1) == lowerDialog &&
                Ops.get_string(dialog, "stage", "initial") == stage
              Ops.set(dialog, "dialog", dialog_id)
            end
            deep_copy(dialog)
          end
          UI.ChangeWidget(Id(:dialogs), :CurrentItem, lowerDialog)
        elsif ret == :questionUp
          dialog_id = Convert.to_integer(
            UI.QueryWidget(Id(:dialogs), :CurrentItem)
          )
          element_id = Convert.to_integer(
            UI.QueryWidget(Id(:questions), :CurrentItem)
          )
          upper = -10
          Builtins.foreach(askList) do |dialog|
            if dialog_id == Ops.get_integer(dialog, "dialog", -1) &&
                Ops.get_string(dialog, "stage", "initial") == stage &&
                Ops.less_than(
                  Ops.get_integer(dialog, "element", -1),
                  element_id
                )
              upper = Ops.get_integer(dialog, "element", -1)
            end
          end
          askList = Builtins.maplist(askList) do |dialog|
            if dialog_id == Ops.get_integer(dialog, "dialog", -1)
              if upper != -10 &&
                  Ops.get_integer(dialog, "element", -1) == element_id &&
                  Ops.get_string(dialog, "stage", "initial") == stage
                Ops.set(dialog, "element", upper)
              elsif Ops.get_integer(dialog, "element", -1) == upper &&
                  Ops.get_string(dialog, "stage", "initial") == stage
                Ops.set(dialog, "element", element_id)
              end
            end
            deep_copy(dialog)
          end
        elsif ret == :questionDown
          dialog_id = Convert.to_integer(
            UI.QueryWidget(Id(:dialogs), :CurrentItem)
          )
          element_id = Convert.to_integer(
            UI.QueryWidget(Id(:questions), :CurrentItem)
          )
          lower = -10
          found = false
          Builtins.foreach(askList) do |dialog|
            if found && Ops.get_string(dialog, "stage", "initial") == stage &&
                Ops.get_integer(dialog, "dialog", -1) == dialog_id
              lower = Ops.get_integer(dialog, "element", -2)
              raise Break
            end
            if Ops.get_integer(dialog, "dialog", -2) == dialog_id &&
                Ops.get_integer(dialog, "element", -2) == element_id
              found = true
            end
          end
          askList = Builtins.maplist(askList) do |dialog|
            if lower != -10 &&
                Ops.get_integer(dialog, "dialog", -1) == dialog_id &&
                Ops.get_string(dialog, "stage", "initial") == stage &&
                Ops.get_integer(dialog, "element", -1) == element_id
              Ops.set(dialog, "element", lower)
            elsif Ops.get_integer(dialog, "dialog", -1) == dialog_id &&
                Ops.get_string(dialog, "stage", "initial") == stage &&
                Ops.get_integer(dialog, "element", -1) == lower
              Ops.set(dialog, "element", element_id)
            end
            deep_copy(dialog)
          end
        elsif ret == :addDialog
          max = -1
          Builtins.foreach(askList) do |m|
            if Ops.get_string(m, "stage", "initial") == stage &&
                Ops.greater_than(Ops.get_integer(m, "dialog", 0), max)
              max = Ops.get_integer(m, "dialog", 0)
            end
          end
          max = Ops.add(max, 1)
          askList = Builtins.add(
            askList,
            "dialog"   => max,
            "title"    => Convert.to_string(
              UI.QueryWidget(Id(:dialogTitle), :Value)
            ),
            "help"     => Convert.to_string(UI.QueryWidget(Id(:hlp), :Value)),
            "question" => _("Edit Question"),
            "element"  => 0,
            "stage"    => stage
          )
        end
        questions = []
        askList = Builtins.sort(askList) do |x, y|
          Ops.less_than(
            Ops.get_integer(x, "dialog", -2),
            Ops.get_integer(y, "dialog", -1)
          ) ||
            Ops.get_integer(x, "dialog", -2) == Ops.get_integer(y, "dialog", -1) &&
              Ops.less_than(
                Ops.get_integer(x, "element", -2),
                Ops.get_integer(y, "element", -1)
              )
        end
        dialogs = []
        done2 = { "initial" => [], "cont" => [] }
        Builtins.foreach(askList) do |m|
          if Ops.get_string(m, "stage", "initial") == stage &&
              !Builtins.contains(
                Ops.get(done2, stage, []),
                Ops.get_integer(m, "dialog", -1)
              )
            dialogs = Builtins.add(
              dialogs,
              Item(
                Id(Ops.get_integer(m, "dialog", -1)),
                Ops.get_string(m, "title", "")
              )
            )
            Ops.set(
              done2,
              stage,
              Builtins.add(
                Ops.get(done2, stage, []),
                Ops.get_integer(m, "dialog", -1)
              )
            )
          end
        end
        dialog_id = Convert.to_integer(
          UI.QueryWidget(Id(:dialogs), :CurrentItem)
        )
        UI.ChangeWidget(Id(:dialogs), :Items, dialogs)
        if ret == :stage_cont || ret == :stage_initial || dialog_id.nil?
          UI.ChangeWidget(Id(:dialogs), :CurrentItem, 0)
        else
          UI.ChangeWidget(Id(:dialogs), :CurrentItem, dialog_id)
        end
        dialog_id = Convert.to_integer(
          UI.QueryWidget(Id(:dialogs), :CurrentItem)
        )
        d2 = Builtins.filter(askList) do |dummy|
          Ops.get_integer(dummy, "dialog", -2) == dialog_id &&
            stage == Ops.get_string(dummy, "stage", "initital")
        end
        d2 = Builtins.sort(d2) do |x, y|
          Ops.less_than(
            Ops.get_integer(x, "element", -2),
            Ops.get_integer(y, "element", -1)
          )
        end
        UI.ChangeWidget(
          Id(:dialogTitle),
          :Value,
          Ops.get_string(d2, [0, "title"], "")
        )
        UI.ChangeWidget(Id(:hlp), :Value, Ops.get_string(d2, [0, "help"], ""))
        id_counter2 = 0
        Builtins.foreach(d2) do |m|
          id_counter2 = Ops.get_integer(m, "element", id_counter2)
          questions = Builtins.add(
            questions,
            Item(Id(id_counter2), Ops.get_string(m, "question", ""))
          )
          id_counter2 = Ops.add(id_counter2, 1)
        end
        UI.ChangeWidget(Id(:questions), :Items, questions)
        UI.ChangeWidget(Id(:dialogs), :CurrentItem, dialog_id)

        AutoinstGeneral.askList = deep_copy(askList) if ret == :next
      end until ret == :next || ret == :back || ret == :cancel
      Convert.to_symbol(ret)
    end

    # Dialog for General Settings
    # @return [Symbol]
    def generalSequence
      dialogs = {
        "mode" => lambda do
          ModeDialog()
        end,
        "ask"  => lambda do
          askDialog
        end
      }

      sequence = {
        "ws_start" => "mode",
        "mode"     => { next: "ask", abort: :abort },
        "ask"      => { next: :finish }
      }
      # Translators: dialog caption
      caption = _("General Settings")
      contents = Label(_("Initializing ..."))

      Wizard.CreateDialog
      Wizard.SetContents(caption, contents, "", true, true)

      ret = Sequencer.Run(dialogs, sequence)

      Wizard.CloseDialog
      Builtins.y2milestone(" generalSequence returns: %1", ret)
      Convert.to_symbol(ret)
    end
  end
end
