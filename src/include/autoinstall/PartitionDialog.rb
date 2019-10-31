# File:  clients/autoinst_storage.ycp
# Package:  Autoinstallation Configuration System
# Summary:  Storage
# Authors:  Anas Nashif<nashif@suse.de>
#
# $Id$
module Yast
  module AutoinstallPartitionDialogInclude
    def initialize_autoinstall_PartitionDialog(include_target)
      textdomain "autoinst"

      Yast.include include_target, "autoinstall/common.rb"
      Yast.include include_target, "autoinstall/AdvancedPartitionDialog.rb"
      Yast.import "AutoinstPartPlan"
      Yast.import "AutoinstDrive"
      Yast.import "AutoinstPartition"

      @currentPartition = {}
      @parentDrive = {}
      @driveId = 0
      @partitionIdx = 0
      @dirty = false

      @partitionType = "part"
      @partitionDialog = {
        type:         @partitionType,
        display:      -> { PartitionDisplay() },
        eventHandler: -> { PartitionEventHandler() },
        store:        -> { PartitionStore() },
        new:          -> { PartitionNew() },
        delete:       -> { PartitionDelete() },
        check:        -> { PartitionCheck() }
      }
      Builtins.y2milestone("adding partition dialog to dialog list.")
      @dialogs = Builtins.add(@dialogs, @partitionType, @partitionDialog)
    end

    def getAvailableMountPoints
      # TODO: implement filtering out already used mp's
      AutoinstPartPlan.getAvailableMountPoints
    end

    def getValidUnitsForMountPoint(mountPoint)
      unit = AutoinstPartition.getAllUnits
      # filter out "auto"
      if "/boot" == mountPoint || "swap" == mountPoint
        # 'auto' is only available for '/boot' and 'swap'
        unit = Builtins.add(unit, "auto")
      end
      toItemList(unit)
    end

    def getFileSystemTypes
      # return toItemList( AutoinstPartition::getAllFileSystemTypes() );
      allFs = AutoinstPartition.getAllFileSystemTypes
      result = []
      Builtins.foreach(allFs) do |fsType, fsMap|
        result = Builtins.add(
          result,
          Item(Id(fsType), Ops.get_string(fsMap, :name, "no-text"))
        )
      end
      Builtins.add(result, Item(Id(:keep), "<keep>"))
    end

    def getFormatStatus
      AutoinstPartition.getFormat(@currentPartition)
    end

    def getMaxPartitionNumber
      AutoinstPartition.getMaxPartitionNumber
    end
    # determines if this partition is a PV feeding VG

    def isPartOfVolgroup
      AutoinstPartition.isPartOfVolgroup(@currentPartition)
    end
    # determines if this partition is to be created on a VG

    def isOnVolgroup
      :CT_DISK != Ops.get_symbol(@parentDrive, "type", :Empty)
    end

    def getVolgroups
      Builtins.add(
        toItemList(AutoinstPartPlan.getAvailableVolgroups),
        Item(Id(:none), _("<none>"))
      )
    end

    def enableMount
      UI.ChangeWidget(Id(:cbMountPoint), :Enabled, true)
      UI.ChangeWidget(Id(:cbFileSystem), :Enabled, true)
      UI.ChangeWidget(Id(:cbVolgroup), :Value, :none)

      nil
    end

    def disableMount
      UI.ChangeWidget(Id(:cbMountPoint), :Enabled, false)
      UI.ChangeWidget(Id(:cbFileSystem), :Value, :keep)
      UI.ChangeWidget(Id(:cbFileSystem), :Enabled, false)

      nil
    end
    # SYNCING UI <-> DATA

    # Sync. UI Settings to currentPartition map.

    def updatePartitionDialogData(part)
      part = deep_copy(part)
      mpString = ""
      lvName = ""
      lvmGroup = ""
      stripes = 1
      stripesize = 0
      partId = 131

      mpAny = UI.QueryWidget(Id(:cbMountPoint), :Value)
      if Ops.is_symbol?(mpAny)
        mpString = symbol2string(Convert.to_symbol(mpAny))
      elsif Ops.is_string?(mpAny)
        mpString = Convert.to_string(mpAny)
      end
      if isOnVolgroup
        # LV
        lvName = Convert.to_string(UI.QueryWidget(Id(:lvName), :Value))
        stripes = Convert.to_integer(UI.QueryWidget(Id(:numberStripes), :Value))
        stripesize = Convert.to_integer(UI.QueryWidget(Id(:stripesize), :Value))
        Popup.Warning(_("Provide a logical volume name.")) if "" == lvName
      else
        UI.ChangeWidget(Id(:striping), :Enabled, false)
        if Convert.to_symbol(UI.QueryWidget(Id(:cbVolgroup), :Value)) != :none
          # PV
          # `/dev/system1 -> "system1"
          lvmGroup = removePrefix(
            symbol2string(
              Convert.to_symbol(UI.QueryWidget(Id(:cbVolgroup), :Value))
            ),
            "/dev/"
          )
          partId = 142
          # a PV needs no mount point
          mpString = ""
        end
      end
      partId = 130 if mpString == "swap"
      part = AutoinstPartition.set(part, "partition_id", partId)
      part = AutoinstPartition.set(part, "mount", mpString)
      part = AutoinstPartition.set(part, "lvm_group", lvmGroup)
      part = AutoinstPartition.set(part, "lv_name", lvName)
      if Ops.greater_than(stripes, 1) && Ops.greater_than(stripesize, 0) &&
          Convert.to_boolean(UI.QueryWidget(Id(:striping), :Value))
        part = AutoinstPartition.set(part, "stripes", stripes)
        part = AutoinstPartition.set(part, "stripesize", stripesize)
      else
        part = Builtins.remove(part, "stripes")
        part = Builtins.remove(part, "stripesize")
      end

      unit = symbol2string(Convert.to_symbol(UI.QueryWidget(Id(:unit), :Value)))
      sizeVal = ""
      if unit != "max" && unit != "auto"
        sizeVal = Convert.to_string(UI.QueryWidget(Id(:size), :Value))
        if unit != "%"
          unit = if unit == "Byte"
            # don't save any unit for byte sizes
            ""
          else
            # MB, GB -> M, B
            Builtins.regexpsub(unit, "(.*)B", "\\1")
          end
        end
      end
      encodedSize = Ops.add(sizeVal, unit)
      part = AutoinstPartition.set(part, "size", encodedSize)
      part = AutoinstPartition.set(
        part,
        "partition_nr",
        Builtins.tointeger(UI.QueryWidget(Id(:partitionNumber), :Value))
      )
      reUse = Convert.to_boolean(UI.QueryWidget(Id(:reusePartition), :Value))
      part = AutoinstPartition.set(part, "create", !reUse)
      part = AutoinstPartition.set(
        part,
        "resize",
        Convert.to_boolean(UI.QueryWidget(Id(:resizePartition), :Value))
      )
      if :keep == Convert.to_symbol(UI.QueryWidget(Id(:cbFileSystem), :Value))
        if !reUse && lvmGroup == ""
          Popup.Warning(
            _(
              "You selected to create the partition, but you did not select a valid file\n" \
                "system. Select a valid filesystem to continue.\n"
            )
          )
        end
        part = AutoinstPartition.set(part, "format", false)
        part = AutoinstPartition.set(part, "filesystem", :Empty)
      else
        part = AutoinstPartition.set(part, "format", true)
        part = AutoinstPartition.set(
          part,
          "filesystem",
          Convert.to_symbol(UI.QueryWidget(Id(:cbFileSystem), :Value))
        )
      end
      deep_copy(part)
    end
    # Sync. currentPartition map to UI.

    def updatePartitionDialogGUI
      if isPartOfVolgroup
        # this is a PV feeding a VG
        disableMount
        volgroupName = addPrefix(
          Ops.get_string(@currentPartition, "lvm_group", "not-set"),
          "/dev/"
        )
        UI.ChangeWidget(Id(:cbVolgroup), :Value, string2symbol(volgroupName))
      else
        enableMount
        mountPoint = Ops.get_string(@currentPartition, "mount", "")
        if isOnVolgroup
          # this is a partition on a VG
          lvName = Ops.get_string(@currentPartition, "lv_name", "")
          lvName = AutoinstPartition.getLVNameFor(mountPoint) if "" == lvName
          UI.ChangeWidget(Id(:lvName), :Value, lvName)
          UI.ChangeWidget(
            Id(:stripesize),
            :Value,
            Ops.get_integer(@currentPartition, "stripesize", 0)
          )
          UI.ChangeWidget(
            Id(:numberStripes),
            :Value,
            Ops.get_integer(@currentPartition, "stripes", 1)
          )
          UI.ChangeWidget(Id(:striping), :Enabled, true)
          if Ops.greater_than(
            Ops.get_integer(@currentPartition, "stripes", 1),
            1
          )
            UI.ChangeWidget(Id(:striping), :Value, true)
            UI.ChangeWidget(Id(:numberStripes), :Enabled, true)
            UI.ChangeWidget(Id(:stripesize), :Enabled, true)
          else
            UI.ChangeWidget(Id(:striping), :Value, false)
            UI.ChangeWidget(Id(:numberStripes), :Enabled, false)
            UI.ChangeWidget(Id(:stripesize), :Enabled, false)
          end
        else
          UI.ChangeWidget(Id(:striping), :Value, false)
          UI.ChangeWidget(Id(:striping), :Enabled, false)
          UI.ChangeWidget(Id(:numberStripes), :Enabled, false)
          UI.ChangeWidget(Id(:stripesize), :Enabled, false)
        end
        UI.ChangeWidget(Id(:cbMountPoint), :Value, mountPoint)
      end
      UI.ChangeWidget(Id(:rbLVM), :Enabled, false) if 0 == Builtins.size(getVolgroups)
      # The size string can be either an absolute numerical like
      # 500M or 10G, the string 'max' or a relative percentage
      # like '10%'.
      unit = AutoinstPartition.getUnit(@currentPartition)
      if "max" == unit || "auto" == unit
        UI.ChangeWidget(Id(:size), :Enabled, false)
      else
        partSize = AutoinstPartition.getSize(@currentPartition)
        UI.ChangeWidget(Id(:size), :Value, Builtins.tostring(partSize))
        if unit != "%"
          unit = if unit == ""
            # size strings with no unit are bytes
            "Byte"
          else
            # M, G -> MB, GB
            Ops.add(unit, "B")
          end
        end
      end
      sUnit = string2symbol(unit)
      UI.ChangeWidget(Id(:unit), :Value, sUnit)
      UI.ChangeWidget(
        Id(:partitionNumber),
        :Value,
        Ops.get_integer(@currentPartition, "partition_nr", 0)
      )

      if Ops.get_boolean(@parentDrive, "initialize", false)
        UI.ChangeWidget(Id(:reusePartition), :Enabled, false)
        UI.ChangeWidget(Id(:resizePartition), :Enabled, false)
      else
        if !Ops.get_boolean(@currentPartition, "create", true)
          # reuse
          UI.ChangeWidget(Id(:reusePartition), :Value, true)
          UI.ChangeWidget(Id(:size), :Enabled, false)
          UI.ChangeWidget(Id(:unit), :Enabled, false)
        else
          # create
          UI.ChangeWidget(Id(:resizePartition), :Enabled, false)
        end
        if Ops.get_boolean(@currentPartition, "resize", false)
          UI.ChangeWidget(Id(:resizePartition), :Enabled, true)
          UI.ChangeWidget(Id(:resizePartition), :Value, true)
          if :max != sUnit
            # only enable size text entry, if unit is not max
            UI.ChangeWidget(Id(:size), :Enabled, true)
          end
          # if resize is enabled, definitly enable units combobox,
          # so user can change units
          UI.ChangeWidget(Id(:unit), :Enabled, true)
        end
      end
      if getFormatStatus
        filesystem = AutoinstPartition.getFileSystem(@currentPartition)
        UI.ChangeWidget(Id(:cbFileSystem), :Value, filesystem)
      else
        UI.ChangeWidget(Id(:cbFileSystem), :Value, :keep)
      end

      nil
    end

    def PartitionCheckSanity(partition)
      partition = deep_copy(partition)
      result = false
      errMsg = AutoinstPartition.checkSanity(partition)
      if "" != errMsg
        Popup.Error(errMsg)
      else
        # if errMsg was empty no error was detected.
        result = true
      end
      result
    end
    # GENERAL DIALOG IFACE

    def PartitionLoad(dIdx, pIdx)
      p = AutoinstPartPlan.getPartition(dIdx, pIdx)
      Builtins.y2milestone(
        "Loaded partition '%1' on drive '%2': \n%3",
        pIdx,
        dIdx,
        p
      )
      deep_copy(p)
    end

    def PartitionStore
      @currentPartition = updatePartitionDialogData(@currentPartition)
      Builtins.y2milestone(
        "PartitionStore():\n" \
          "current partiton: '%1'\n" \
          "(driveId:partitionIdx): ('%2':'%3')",
        @currentPartition,
        @driveId,
        @partitionIdx
      )
      # We don't use the return value of the check, because we
      # currently can't stop the dialog switch from happening, so we
      # issue possible errors as warnings, and store anyway... should
      # be fixed.
      PartitionCheckSanity(@currentPartition)
      AutoinstPartPlan.updatePartition(
        @driveId,
        @partitionIdx,
        @currentPartition
      )

      nil
    end

    def PartitionCheck
      unchangedPartition = @currentPartition
      @currentPartition = updatePartitionDialogData(@currentPartition)
      Builtins.y2milestone(
        "PartitionCheck():\n" \
          "current partiton: '%1'\n" \
          "(driveId:partitionIdx): ('%2':'%3')",
        @currentPartition,
        @driveId,
        @partitionIdx
      )

      if !AutoinstPartition.areEqual(@currentPartition, unchangedPartition) || @dirty
        if Popup.YesNo(_("Store unsaved changes to partition?"))
          @dirty = false
          if PartitionCheckSanity(@currentPartition)
            AutoinstPartPlan.updatePartition(
              @driveId,
              @partitionIdx,
              @currentPartition
            )
          end
        end
      end

      nil
    end

    def PartitionDisplay
      reference = Ops.get_string(@stack, :which, "")
      Builtins.y2milestone("PartitionDisplay('%1')", reference)
      splice = Builtins.splitstring(reference, "_")
      @driveId = Builtins.tointeger(Ops.get(splice, 0, "999"))
      @partitionIdx = Builtins.tointeger(Ops.get(splice, 1, "999"))
      @currentPartition = PartitionLoad(@driveId, @partitionIdx)
      @parentDrive = AutoinstPartPlan.getDrive(@driveId)

      lvmSettings = ComboBox(
        Id(:cbVolgroup),
        Opt(:notify),
        _("Volgroup"),
        getVolgroups
      )
      lvmSettings = InputField(Id(:lvName), _("Logical volume name")) if isOnVolgroup
      contents = VBox(
        Heading(_("Edit partition")),
        VSpacing(1),
        HVCenter(
          HVSquash(
            VBox(
              HBox(
                Left(
                  ComboBox(
                    Id(:cbMountPoint),
                    Opt(:editable, :notify),
                    _("&Mount point"),
                    getAvailableMountPoints
                  )
                ),
                HSpacing(1),
                lvmSettings,
                HSpacing(2),
                Right(
                  ComboBox(
                    Id(:cbFileSystem),
                    _("File sys&tem"),
                    getFileSystemTypes
                  )
                )
              ),
              VSpacing(1),
              HBox(
                Left(InputField(Id(:size), _("&Size"))),
                # `TextEntry(`id(`size), _("&Size")),
                Left(
                  ComboBox(
                    Id(:unit),
                    Opt(:notify),
                    " ",
                    getValidUnitsForMountPoint(
                      Ops.get_string(@currentPartition, "mount", "")
                    )
                  )
                ),
                HStretch()
              ), # HBox
              VSpacing(1),
              HBox(
                IntField(
                  Id(:partitionNumber),
                  _("Partiti&on number"),
                  0,
                  getMaxPartitionNumber,
                  Ops.get_integer(@currentPartition, "partition_nr", 0)
                ), # VBox
                HStretch(),
                VBox(
                  Left(
                    CheckBox(
                      Id(:reusePartition),
                      Opt(:notify),
                      _("Reuse e&xisting partition")
                    )
                  ),
                  Left(
                    CheckBox(
                      Id(:resizePartition),
                      Opt(:notify),
                      _("Res&ize existing partition")
                    )
                  )
                )
              ), # HBox
              VSpacing(1),
              HBox(
                CheckBox(Id(:striping), Opt(:notify), _("Activate Striping")),
                IntField(
                  Id(:numberStripes),
                  Opt(:notify),
                  _("Number of Stripes"),
                  1,
                  9,
                  1
                ),
                IntField(
                  Id(:stripesize),
                  Opt(:notify),
                  _("Stripe size"),
                  1,
                  32,
                  1
                ),
                HStretch()
              ), # HBox
              VSpacing(1),
              PushButton(Id(:advanced), _("Advan&ced")),
              VSpacing(2),
              PushButton(Id(:apply), _("Apply"))
            ) # VBox
          ) # HVCenter
        )
      ) # VBox
      UI.ReplaceWidget(Id(@replacement_point), contents)
      # only numbers are allowed in size
      UI.ChangeWidget(Id(:size), :ValidChars, "0123456789")
      UI.ChangeWidget(Id(:striping), :Enabled, isOnVolgroup)
      UI.ChangeWidget(
        Id(:numberStripes),
        :Enabled,
        Convert.to_boolean(UI.QueryWidget(Id(:striping), :Value))
      )
      UI.ChangeWidget(
        Id(:stripesize),
        :Enabled,
        Convert.to_boolean(UI.QueryWidget(Id(:striping), :Value))
      )
      updatePartitionDialogGUI

      # Setting currentPartition to some default entries made by
      # the UI design.
      @currentPartition = updatePartitionDialogData(@currentPartition)
      nil
    end

    def PartitionNew
      parentDriveId = Builtins.tointeger(Ops.get_string(@stack, :which, "0"))
      newPartitionNumber = AutoinstPartPlan.newPartition(parentDriveId)
      if newPartitionNumber != 999
        parentDrive = AutoinstPartPlan.getDrive(parentDriveId)
        parentRef = AutoinstDrive.getNodeReference(parentDrive)
        newPartitionId = AutoinstPartition.getNodeReference(
          parentRef,
          newPartitionNumber
        )
        Ops.set(@stack, :which, stripTypePrefix(newPartitionId))
        PartitionDisplay()
        selectTreeItem(newPartitionId)
      else
        Builtins.y2error(
          "Cannot create new partition an invalid drive with index '%1'.",
          parentDriveId
        )
      end

      nil
    end

    def PartitionEventHandler
      Builtins.y2milestone("PartitionEventHandler():")
      if Ops.is_map?(@currentEvent)
        event = Ops.get_symbol(@currentEvent, "WidgetID", :Empty)
        if :cbVolgroup == event
          if :none == Convert.to_symbol(UI.QueryWidget(Id(:cbVolgroup), :Value))
            # user selected this partition _not_ to be part of volgroup
            enableMount
          else
            # user selected this partition to be part of volgroup
            disableMount
          end
          eventHandled
        elsif :unit == event
          which = Convert.to_symbol(UI.QueryWidget(Id(:unit), :Value))
          if :max == which
            UI.ChangeWidget(Id(:size), :Enabled, false)
          elsif :auto == which
            if Convert.to_boolean(UI.QueryWidget(Id(:cbMountPoint), :Enabled))
              mp = Convert.to_string(UI.QueryWidget(Id(:cbMountPoint), :Value))
              if "/boot" == mp || "swap" == mp
                UI.ChangeWidget(Id(:size), :Enabled, false)
              else
                Popup.Error(
                  _(
                    "Size \"auto\" is only valid if mount point \"/boot\" or \"swap\" is selected."
                  )
                )
                UI.ChangeWidget(Id(:size), :Enabled, true)
                UI.ChangeWidget(Id(:unit), :Value, :GB)
              end
            else
              Popup.Error(_("Size \"auto\" is invalid for physical volumes."))
              UI.ChangeWidget(Id(:size), :Enabled, true)
              UI.ChangeWidget(Id(:unit), :Value, :GB)
            end
          else
            UI.ChangeWidget(Id(:size), :Enabled, true)
          end
          eventHandled
        elsif :advanced == event
          # if this partition is part of a volume group,
          # we call it a PV (physical volume).
          isPV = UI.WidgetExists(Id(:cbVolgroup)) &&
            :none != Convert.to_symbol(UI.QueryWidget(Id(:cbVolgroup), :Value))
          @currentPartition = AdvancedPartitionDisplay(@currentPartition, isPV)
          Builtins.y2milestone("got partition '%1'", @currentPartition)
        elsif :reusePartition == event
          reuseEnabled = Convert.to_boolean(
            UI.QueryWidget(Id(:reusePartition), :Value)
          )
          if reuseEnabled
            UI.ChangeWidget(Id(:size), :Enabled, false)
            UI.ChangeWidget(Id(:unit), :Enabled, false)
            UI.ChangeWidget(Id(:resizePartition), :Enabled, true)
          else
            # reuse has been disabled
            UI.ChangeWidget(Id(:unit), :Enabled, true)
            if :max != Convert.to_symbol(UI.QueryWidget(Id(:unit), :Value))
              UI.ChangeWidget(Id(:size), :Enabled, true)
            end
            UI.ChangeWidget(Id(:resizePartition), :Value, false)
            UI.ChangeWidget(Id(:resizePartition), :Enabled, false)
          end
        elsif :resizePartition == event
          resizeEnabled = Convert.to_boolean(
            UI.QueryWidget(Id(:resizePartition), :Value)
          )
          if resizeEnabled
            # resize has been enabled
            if :max != Convert.to_symbol(UI.QueryWidget(Id(:unit), :Value))
              UI.ChangeWidget(Id(:size), :Enabled, true)
            end
            UI.ChangeWidget(Id(:unit), :Enabled, true)
          else
            # resize has been disabled
            UI.ChangeWidget(Id(:size), :Enabled, false)
            UI.ChangeWidget(Id(:unit), :Enabled, false)
          end
        elsif :cbMountPoint == event
          mp = UI.QueryWidget(Id(:cbMountPoint), :Value)
          mountPoint = ""
          mountPoint = if Ops.is_symbol?(mountPoint)
            symbol2string(Convert.to_symbol(mp))
          else
            Convert.to_string(mp)
          end
          prevUnit = Convert.to_symbol(UI.QueryWidget(Id(:unit), :Value))
          # rebuild unit list
          UI.ChangeWidget(
            Id(:unit),
            :Items,
            getValidUnitsForMountPoint(mountPoint)
          )
          if :auto == prevUnit && "/boot" != mountPoint && "swap" != mountPoint
            UI.ChangeWidget(Id(:size), :Enabled, true)
            # as 'auto' is no longer available select GB as default
            prevUnit = :GB
          end
          # reselect previous unit
          UI.ChangeWidget(Id(:unit), :Value, prevUnit)
          if mountPoint == "swap"
            UI.ChangeWidget(Id(:cbFileSystem), :Value, :swap)
            UI.ChangeWidget(Id(:cbFileSystem), :Enabled, false)
          end
        elsif event == :striping
          UI.ChangeWidget(Id(:numberStripes), :Value, 1)
          UI.ChangeWidget(
            Id(:numberStripes),
            :Enabled,
            Convert.to_boolean(UI.QueryWidget(Id(:striping), :Value))
          )
          UI.ChangeWidget(
            Id(:stripesize),
            :Enabled,
            Convert.to_boolean(UI.QueryWidget(Id(:striping), :Value))
          )
          @dirty = true
        end
      end

      nil
    end

    def PartitionDelete
      reference = Ops.get_string(@stack, :which, "")
      Builtins.y2milestone("PartitionDelete('%1')", reference)
      # PartitionDelete is only called when a partition is selected,
      # so driveId and partitionIdx should have valid values.
      AutoinstPartPlan.deletePartition(@driveId, @partitionIdx)

      nil
    end
  end
end
