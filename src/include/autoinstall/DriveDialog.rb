# File:  clients/autoinst_storage.ycp
# Package:  Autoinstallation Configuration System
# Summary:  Storage
# Authors:  Anas Nashif<nashif@suse.de>
#
# $Id$
module Yast
  module AutoinstallDriveDialogInclude
    def initialize_autoinstall_DriveDialog(include_target)
      textdomain "autoinst"

      Yast.include include_target, "autoinstall/common.rb"
      Yast.include include_target, "autoinstall/types.rb"

      Yast.import "Popup"

      Yast.import "AutoinstPartPlan"
      Yast.import "AutoinstDrive"

      # INTERNAL STUFF

      # local copy of current device the user wants to
      # edit using this dialog
      @currentDrive = {}
      @currentDriveIdx = 999

      @allDevices = [
        "auto",
        "/dev/hda",
        "/dev/hdb",
        "/dev/hdc",
        "/dev/sda",
        "/dev/sdb"
      ]
      @reuseTypes = ["all", "free", "linux"]

      @driveDialogTitle = _("Edit Drive")

      # INITIALIZE DIALOG
      @driveType = "drive"
      @driveDialog = {
        type:         @driveType,
        display:      -> { DriveDisplay() },
        eventHandler: -> { DriveEventHandler() },
        store:        -> { DriveStore() },
        new:          -> { DriveNew() },
        delete:       -> { DriveDelete() },
        check:        -> { DriveCheck() }
      }
      Builtins.y2milestone("adding drive dialog to dialog list.")
      @dialogs = Builtins.add(@dialogs, @driveType, @driveDialog)
    end

    def enableReuse(selected)
      selected = deep_copy(selected)
      UI.ChangeWidget(Id(:cb_reuse), :Value, selected) if !selected.nil? && Ops.is_symbol?(selected)
      UI.ChangeWidget(Id(:cb_reuse), :Enabled, true)
      if UI.QueryWidget(Id(:rbg), :CurrentButton) != :rb_reuse
        UI.ChangeWidget(Id(:rbg), :CurrentButton, :rb_reuse)
      end

      nil
    end

    def disableReuse
      UI.ChangeWidget(Id(:cb_reuse), :Value, :all)
      UI.ChangeWidget(Id(:cb_reuse), :Enabled, false)
      if UI.QueryWidget(Id(:rbg), :CurrentButton) != :rb_init
        UI.ChangeWidget(Id(:rbg), :CurrentButton, :rb_init)
      end

      nil
    end

    # SYNCING GUI <-> DATA

    def updateGUI(d)
      drive = Ops.get_string(
        AutoinstPartPlan.getDrive(Builtins.tointeger(d)),
        "device",
        ""
      )
      UI.ChangeWidget(Id(:device), :Value, string2symbol(drive))
      if Ops.get_boolean(@currentDrive, "initialize", false) == true
        disableReuse
      else
        enableReuse(Ops.get(@currentDrive, "use"))
      end

      nil
    end

    def updateData(drive)
      drive = deep_copy(drive)
      drive = AutoinstDrive.set(
        drive,
        "device",
        symbol2string(Convert.to_symbol(UI.QueryWidget(Id(:device), :Value)))
      )
      if UI.QueryWidget(Id(:rbg), :CurrentButton) == :rb_init
        drive = AutoinstDrive.set(drive, "initialize", true)
        drive = AutoinstDrive.set(drive, "use", :all)
      else
        drive = AutoinstDrive.set(drive, "initialize", false)
        drive = AutoinstDrive.set(
          drive,
          "use",
          symbol2string(UI.QueryWidget(Id(:cb_reuse), :Value))
        )
      end
      deep_copy(drive)
    end

    # GENERAL DIALOG IFACE
    def DriveLoad(driveIdx)
      drive = AutoinstPartPlan.getDrive(driveIdx)
      Builtins.y2milestone("loaded drive('%1'): '%2'", driveIdx, drive)
      if !Builtins.contains(@allDevices, Ops.get_string(drive, "device", ""))
        @allDevices = Builtins.add(
          @allDevices,
          Ops.get_string(drive, "device", "")
        )
      end
      deep_copy(drive)
    end

    def DriveStore
      @currentDrive = updateData(@currentDrive)
      AutoinstPartPlan.updateDrive(@currentDrive)
      Builtins.y2milestone(
        "updated drive('%1'): '%2'",
        Ops.get_string(@currentDrive, "device", ""),
        @currentDrive
      )

      nil
    end

    def DriveCheck
      @currentDrive = updateData(@currentDrive)
      storedDrive = DriveLoad(@currentDriveIdx)
      if !AutoinstDrive.areEqual(@currentDrive, storedDrive)
        if Popup.YesNo("Store unsaved changes to drive?")
          AutoinstPartPlan.updateDrive(@currentDrive)
        end
      end

      nil
    end

    def DriveDisplay
      drive = Ops.get_string(@stack, :which, "")
      Builtins.y2milestone("DriveDisplay('%1')", drive)
      @currentDriveIdx = Builtins.tointeger(drive)
      @currentDrive = DriveLoad(@currentDriveIdx)

      contents = VBox(
        Heading(@driveDialogTitle),
        HVCenter(
          HVSquash(
            VBox(
              ComboBox(
                Id(:device),
                Opt(:editable),
                _("D&evice"),
                toItemList(@allDevices)
              ),
              VSpacing(1),
              RadioButtonGroup(
                Id(:rbg),
                VBox(
                  Left(
                    RadioButton(
                      Id(:rb_init),
                      Opt(:notify),
                      _("&Intialize drive")
                    )
                  ),
                  # initially selected
                  Left(
                    RadioButton(Id(:rb_reuse), Opt(:notify), _("Re&use"), true)
                  ),
                  ComboBox(
                    Id(:cb_reuse),
                    Opt(:editable),
                    _("&Type"),
                    toItemList(@reuseTypes)
                  )
                )
              ),
              VSpacing(2),
              PushButton(Id(:apply), _("Apply"))
            )
          )
        )
      )
      UI.ReplaceWidget(Id(@replacement_point), contents)
      updateGUI(drive)

      nil
    end

    def DriveEventHandler
      Builtins.y2milestone(
        "DriveEventHandler(): current event: '%1'",
        @currentEvent
      )
      if Ops.is_map?(@currentEvent)
        if :rb_init == Ops.get_symbol(@currentEvent, "WidgetID", :Empty)
          # initialize drive -> set reuse type to all and disable combobox
          disableReuse
          eventHandled
        elsif :rb_reuse == Ops.get_symbol(@currentEvent, "WidgetID", :Empty)
          # reuse drive -> enable combobox
          enableReuse(nil)
          eventHandled
        end
      end

      nil
    end

    def DriveDelete
      drive = Ops.get_string(@stack, :which, "")
      Builtins.y2milestone("DriveDelete('%1')", drive)
      AutoinstPartPlan.removeDrive(Builtins.tointeger(drive))

      nil
    end

    def DriveNew
      # TODO: implement default name
      defaultDevice = "auto"
      newDrive = AutoinstPartPlan.addDrive(
        AutoinstDrive.new(defaultDevice, :CT_DISK)
      )
      selectTreeItem(AutoinstDrive.getNodeReference(newDrive))
      Ops.set(
        @stack,
        :which,
        Builtins.tostring(Ops.get_integer(newDrive, "_id", 999))
      )
      DriveDisplay()

      nil
    end
  end
end
