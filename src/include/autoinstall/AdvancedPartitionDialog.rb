# encoding: utf-8

# File:
#  AdvancedPartitionDialog.ycp
#
# Module:
#  Partitioning
#
# Summary:
#  Display and handle advanced partition dialog.
#
# Authors:
#  Sven Schober (sschober@suse.de)
#
# $Id: AdvancedPartitionDialog.ycp 2788 2008-05-13 10:00:17Z sschober $
module Yast
  module AutoinstallAdvancedPartitionDialogInclude
    def initialize_autoinstall_AdvancedPartitionDialog(include_target)
      Yast.import "UI"
      textdomain "autoinst"

      Yast.include include_target, "autoinstall/common.rb"

      Yast.import "AutoinstPartPlan"
      Yast.import "AutoinstDrive"
      Yast.import "AutoinstPartition"
      Yast.import "Label"
    end

    def encryptionEnabled(part)
      part = deep_copy(part)
      Ops.get_boolean(part, "crypt_fs", false)
    end

    def fstabOptionsEnabled(_part)
      false
    end

    def mkRadioButton(part, name, label)
      part = deep_copy(part)
      # Constructs buttons like this
      #
      #  `Left(`RadioButton(`id(`rbMB_name),_("Device name"))),
      Left(
        RadioButton(
          Id(name),
          label,
          Ops.get_symbol(part, "mountby", :Empty) == name
        )
      )
    end

    def AdvancedPartitionDisplay(part, isPV)
      part = deep_copy(part)
      # is result copy of part?
      result = deep_copy(part)

      cryptFrame = CheckBoxFrame(
        Id(:cbfCrypt),
        _("Encryption"),
        encryptionEnabled(part),
        TextEntry(
          Id(:crypt_key),
          _("Encryption key"),
          Ops.get_string(part, "crypt_key", "No key set")
        )
      )
      if isPV
        cryptFrame = Frame(
          _("Encryption"),
          Label(_("Encryption is not available for physical volumes"))
        )
      end
      contents = HBox(
        HSpacing(1),
        HWeight(
          70,
          HCenter(
            VBox(
              Heading(_("Advanced Partition Settings")),
              VCenter(
                VBox(
                  cryptFrame,
                  VSpacing(1),
                  VSquash(
                    Frame(
                      _("Fstab options"),
                      VBox(
                        Left(Label(_("Mount by"))),
                        RadioButtonGroup(
                          Id(:rbgMountBy),
                          HBox(
                            Top(
                              VBox(
                                mkRadioButton(part, :device, _("Device name")),
                                mkRadioButton(part, :id, _("Device id")),
                                mkRadioButton(part, :label, _("Volume label"))
                              )
                            ),
                            Top(
                              VBox(
                                mkRadioButton(part, :path, _("Device path")),
                                mkRadioButton(part, :uuid, _("UUID"))
                              )
                            )
                          )
                        ),
                        Top(
                          TextEntry(
                            Id(:volLabel),
                            _("Volume label"),
                            Ops.get_string(part, "label", "No options set")
                          )
                        )
                      )
                    )
                  ),
                  VSpacing(1),
                  ButtonBox(
                    PushButton(Id(:pbCancel), Label.CancelButton),
                    PushButton(Id(:pbOK), Label.OKButton)
                  )
                )
              ),
              VStretch()
            )
          )
        ),
        HSpacing(1)
      )
      # Setting the option `defaultsize here causes the main dialog (the one
      # with the tree on the left) to be replaced by this one, which might be
      # a bit irritating... but otherwise the dialog is too small.
      UI.OpenDialog(Opt(), contents)
      UI.ChangeWidget(
        Id(:crypt_key),
        :ValidChars,
        "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" \
          "#* ,.;:._-+!$%&/|?{[()]}@^\\<>"
      )

      # Disable all mount options if partition is a
      # physical volumen
      if isPV
        # TODO: disabling cbfCrypt doesn't work
        widgets = [:device, :id, :label, :path, :uuid]
        Builtins.foreach(widgets) do |widget|
          UI.ChangeWidget(Id(widget), :Enabled, false)
        end
      end
      widgetID = Convert.to_symbol(UI.UserInput)

      while widgetID != :pbCancel && widgetID != :pbOK
        if :pbFsOpts == widgetID
          # segfaults
          # FstabOptions( part, result );
          # so for the time being
          Ops.set(result, "fstopt", UI.QueryWidget(Id(:fsOpts), :Value))
          UI.ChangeWidget(
            Id(:fsOpts),
            :Value,
            Ops.get_string(result, "fstopt", "")
          )
        end
        widgetID = Convert.to_symbol(UI.UserInput)
      end

      if :pbCancel == widgetID
        # discard changes and return part
        UI.CloseDialog
        return deep_copy(part)
      end
      # store dialog changes in result
      if true == UI.QueryWidget(Id(:cbfCrypt), :Value)
        Ops.set(result, "crypt_fs", true)
        Ops.set(result, "crypt_key", UI.QueryWidget(Id(:crypt_key), :Value))
        Ops.set(result, "crypt", "twofish256")
      end
      Ops.set(result, "label", UI.QueryWidget(Id(:volLabel), :Value))
      Ops.set(result, "mountby", UI.QueryWidget(Id(:rbgMountBy), :Value))
      UI.CloseDialog
      deep_copy(result)
    end
  end
end
