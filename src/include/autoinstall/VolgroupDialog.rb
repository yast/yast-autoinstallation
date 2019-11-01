# File:  clients/autoinst_storage.ycp
# Package:  Autoinstallation Configuration System
# Summary:  Storage
# Authors:  Anas Nashif<nashif@suse.de>
#
# $Id$
module Yast
  module AutoinstallVolgroupDialogInclude
    def initialize_autoinstall_VolgroupDialog(include_target)
      textdomain "autoinst"

      Yast.include include_target, "autoinstall/common.rb"
      Yast.include include_target, "autoinstall/types.rb"

      Yast.import "AutoinstPartPlan"
      Yast.import "AutoinstDrive"

      # INTERNAL STUFF

      # local copy of current device the user wants to
      # edit using this dialog
      @currentVolgroup = {}
      @currentVolgroupIdx = 999

      @volgroupTypes = ["LVM"]
      @volgroupTypePrefix = "CT_"

      @volgroupPrefix = "/dev/"
      @newVolgroupName = "NewVg"

      @volgroupDialogTitle = _("Edit Volume Group")

      # INITIALIZE DIALOG
      @volgroupType = "volgroup"
      @volgroupDialog = {
        type:         @volgroupType,
        display:      -> { VolgroupDisplay() },
        eventHandler: -> { VolgroupEventHandler() },
        store:        -> { VolgroupStore() },
        new:          -> { VolgroupNew() },
        delete:       -> { VolgroupDelete() },
        check:        -> { VolgroupCheck() }
      }
      Builtins.y2milestone("adding volgroup dialog to dialog list.")
      addDialog(@volgroupType, @volgroupDialog)
    end

    # SYNCING GUI <-> DATA

    def VolgroupAddTypePrefix(s)
      string2symbol(addPrefix(symbol2string(s), @volgroupTypePrefix))
    end

    def VolgroupRemoveTypePrefix(s)
      string2symbol(removePrefix(symbol2string(s), @volgroupTypePrefix))
    end

    def VolgroupUpdateGUI(_d)
      UI.ChangeWidget(
        Id(:vgDevice),
        :Value,
        removePrefix(
          Ops.get_string(@currentVolgroup, "device", "<not-set>"),
          @volgroupPrefix
        )
      )
      #    symbol vgType = VolgroupRemoveTypePrefix( currentVolgroup["type"]:`CT_LVM );
      #    UI::ChangeWidget( `id(`vgType), `Value, vgType);

      nil
    end

    def VolgroupUpdateData(vg)
      vg = deep_copy(vg)
      # TODO: device name constraints
      vg = AutoinstDrive.set(
        vg,
        "device",
        addPrefix(
          Convert.to_string(UI.QueryWidget(Id(:vgDevice), :Value)),
          @volgroupPrefix
        )
      )
      #     symbol vgType = VolgroupAddTypePrefix( (symbol)UI::QueryWidget(`id(`vgType), `Value) );
      #      vg = AutoinstDrive::set(vg, "type", vgType );
      deep_copy(vg)
    end

    # GENERAL DIALOG IFACE
    def VolgroupLoad(drive)
      vg = AutoinstPartPlan.getDrive(drive)
      Builtins.y2milestone("loaded drive('%1'): '%2'", drive, vg)
      deep_copy(vg)
    end

    def VolgroupStore
      @currentVolgroup = VolgroupUpdateData(@currentVolgroup)
      AutoinstPartPlan.updateDrive(@currentVolgroup)
      Builtins.y2milestone(
        "updated drive('%1'): '%2'",
        Ops.get_string(@currentVolgroup, "device", ""),
        @currentVolgroup
      )

      nil
    end

    def VolgroupCheck
      @currentVolgroup = VolgroupUpdateData(@currentVolgroup)
      storedVolgroup = AutoinstPartPlan.getDrive(@currentVolgroupIdx)
      if !AutoinstDrive.areEqual(@currentVolgroup, storedVolgroup)
        if Popup.YesNo(_("Store unsaved changes to volume group?"))
          AutoinstPartPlan.updateDrive(@currentVolgroup)
        end
      end
      Builtins.y2milestone(
        "updated drive('%1'): '%2'",
        Ops.get_string(@currentVolgroup, "device", ""),
        @currentVolgroup
      )

      nil
    end

    def VolgroupDisplay
      drive = Ops.get_string(@stack, :which, "")
      Builtins.y2milestone("VolgroupDisplay('%1')", drive)
      @currentVolgroupIdx = Builtins.tointeger(drive)
      @currentVolgroup = VolgroupLoad(@currentVolgroupIdx)

      contents = VBox(
        Heading(@volgroupDialogTitle),
        HVCenter(
          HVSquash(
            VBox(
              TextEntry(Id(:vgDevice), _("Volgroup device name")),
              # `ComboBox( `id(`vgType), _("Type"), toItemList(volgroupTypes)),
              VSpacing(2),
              PushButton(Id(:apply), _("Apply"))
            )
          )
        )
      )
      UI.ReplaceWidget(Id(@replacement_point), contents)
      VolgroupUpdateGUI(drive)

      nil
    end

    def VolgroupEventHandler
      Builtins.y2milestone(
        "VolgroupEventHandler(): current event: '%1'",
        @currentEvent
      )

      nil
    end

    def VolgroupDelete
      drive = Ops.get_string(@stack, :which, "")
      Builtins.y2milestone("VolgroupDelete('%1')", drive)
      AutoinstPartPlan.removeDrive(Builtins.tointeger(drive))

      nil
    end

    def VolgroupNew
      defaultDevice = Ops.add(@volgroupPrefix, @newVolgroupName)
      newDrive = AutoinstPartPlan.addDrive(
        AutoinstDrive.new(defaultDevice, :CT_LVM)
      )
      selectTreeItem(AutoinstDrive.getNodeReference(newDrive))
      Ops.set(
        @stack,
        :which,
        Builtins.tostring(Ops.get_integer(newDrive, "_id", 999))
      )
      VolgroupDisplay()

      nil
    end
  end
end
