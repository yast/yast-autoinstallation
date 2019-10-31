# File:  modules/AutoinstCommon.ycp
# Package:  Auto-installation/Partition
# Summary:  Module representing a partitioning plan
# Author:  Sven Schober (sschober@suse.de)
#
# $Id: AutoinstPartPlan.ycp 2813 2008-06-12 13:52:30Z sschober $
require "yast"
require "y2storage"

module Yast
  class AutoinstPartPlanClass < Module
    include Yast::Logger

    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.include self, "autoinstall/types.rb"
      Yast.include self, "autoinstall/common.rb"
      Yast.include self, "autoinstall/tree.rb"

      Yast.import "AutoinstCommon"
      Yast.import "AutoinstDrive"
      Yast.import "AutoinstPartition"
      Yast.import "Summary"
      Yast.import "Popup"
      Yast.import "Mode"
      Yast.import "Arch"

      # The general idea with this moduls is that it manages a single
      # partition plan (AutoPartPlan) and the user can work on that
      # plan without having to sepcify that variable on each method
      # call.
      # This is on the one hand convenient for the user and on the
      # other hand we have control over the plan.

      # PRIVATE

      # The single plan instance managed by this module.
      #
      # The partition plan is technically a list of DriveT'.
      @AutoPartPlan = []

      # default value of settings modified
      @modified = false

      # Devices which do not have any mount point, lvm_group or raid_name
      # These devices will not be taken in the AutoYaSt configuration file
      # but will be added to the skip_list in order not regarding it while
      # next installation. (bnc#989392)
      @skipped_devices = []
    end

    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      Builtins.y2milestone("SetModified")
      @modified = true

      nil
    end

    # Functions which returns if the settings were modified
    #
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end

    # Select a drive by its ID, as in the tree item strings (e.g.
    # "drive_1" -> ID = 1).
    #
    # @param [Array<Hash{String => Object>}] plan The partition plan
    # @param [Fixnum] which ID of the drive to return
    #
    # @return The drive with the specified id, or the an empty map if
    # no drive with that id exists.

    def internalGetDrive(plan, which)
      plan = deep_copy(plan)
      result = {}
      Builtins.foreach(plan) do |currentDrive|
        if which == Ops.get_integer(currentDrive, "_id", -1)
          result = deep_copy(currentDrive)
          raise Break
        end
      end
      deep_copy(result)
    end

    # Select a drive by its position in the drive list (a.k.a
    # partition plan).
    #
    # @param [Array<Hash{String => Object>}] plan Partition plan.
    # @param [Fixnum] index Index of drive in the list
    #
    # @return The spcified drive, or an empty map if the index wasn't
    # valid.

    def internalGetDriveByListIndex(plan, index)
      plan = deep_copy(plan)
      Ops.get(plan, index, {})
    end

    # Get a list index for a drive id.
    #
    # @param [Array<Hash{String => Object>}] plan Partition plan.
    # @param [Fixnum] which the drive id.
    #
    # @return The list index or -1 if id wasn't found.

    def internalGetListIndex(plan, which)
      plan = deep_copy(plan)
      index = 0
      found = false
      Builtins.foreach(plan) do |currentDrive|
        currentID = Ops.get_integer(currentDrive, "_id", -1)
        if which == currentID
          found = true
          raise Break
        end
        index = Ops.add(index, 1)
      end
      return index if found

      -1
    end

    # ==========
    #  Mutators
    # ==========

    # Add a drive to the partition plan.
    #
    # @param [Array<Hash{String => Object>}] plan Partition plan.
    # @param [Hash{String => Object}] drive The drive to be added
    #
    # @return The partition plan containing the new drive.

    def internalAddDrive(plan, drive)
      plan = deep_copy(plan)
      drive = deep_copy(drive)
      if AutoinstDrive.isDrive(drive)
        # TODO: implement insertion constraints
        return Builtins.add(plan, drive)
      else
        Builtins.y2error("No valid drive '%1'.", drive)
      end

      nil
    end

    # Remove a drive from the plan.
    #
    # @param [Array<Hash{String => Object>}] plan Partition plan.
    # @param [Fixnum] which The id of the drive to remove.
    #
    # @return The partition plan lacking the drive that was removed if
    # it was present.

    def internalRemoveDrive(plan, which)
      plan = deep_copy(plan)
      drive = internalGetDrive(plan, which)
      result = Builtins.filter(plan) do |curDrive|
        Ops.get_integer(drive, "_id", 100) !=
          Ops.get_integer(curDrive, "_id", 111)
      end
      deep_copy(result)
    end

    # Update a drive in the partition plan.
    #
    # @param [Array<Hash{String => Object>}] plan Partition plan.
    # @param [Hash{String => Object}] drive The drive to be updated.
    #
    # @return Partition plan containing the updated drive.

    def internalUpdateDrive(plan, drive)
      plan = deep_copy(plan)
      drive = deep_copy(drive)
      if AutoinstDrive.isDrive(drive)
        plan = Builtins.maplist(@AutoPartPlan) do |curDrive|
          if Ops.get_integer(curDrive, "_id", 100) ==
              Ops.get_integer(drive, "_id", 111)
            next deep_copy(drive)
          else
            next deep_copy(curDrive)
          end
        end
      else
        Builtins.y2error("No valid drive: '%1'", drive)
      end
      deep_copy(plan)
    end

    # Get a list of all drives, that are of a volgroup type.
    #
    # @param [Array<Hash{String => Object>}] _plan The partition plan. Not used as it touch
    #        `@AutoPartPlan` directly.
    #
    # @return Partition plan containing only volgroups.

    def internalGetAvailableVolgroups(_plan)
      result = Builtins.filter(@AutoPartPlan) do |curDrive|
        Ops.get_symbol(curDrive, "type", :CT_DISK) != :CT_DISK
      end
      deep_copy(result)
    end

    # Get a list of all physical (not volgroup) drives.
    #
    # @param [Array<Hash{String => Object>}] _plan The partition plan. Not used as it touch
    #        `@AutoPartPlan` directly.
    #
    # @return Partition plan containing only physical drives.
    def internalGetAvailablePhysicalDrives(_plan)
      result = Builtins.filter(@AutoPartPlan) do |curDrive|
        Ops.get_symbol(curDrive, "type", :CT_LVM) == :CT_DISK
      end
      deep_copy(result)
    end

    # Get a list of used mountpoint strings.
    #
    # @param [Array<Hash{String => Object>}] plan The partition plan.
    #
    # @return A list of mountpoint strings in use by any partition.

    def internalGetUsedMountPoints(plan)
      plan = deep_copy(plan)
      result = []
      Builtins.foreach(plan) do |drive|
        Builtins.foreach(Ops.get_list(drive, "partitions", [])) do |part|
          mountPoint = Ops.get_string(part, "mount", "")
          result = Builtins.add(result, mountPoint) if "" != mountPoint
        end
      end
      Builtins.y2milestone("Used mount points: '%1'", result)
      deep_copy(result)
    end

    # Volume group checks:
    #  - check that each VG has at least one PV
    #   - <others to be implemented>
    #
    # @param [Array<Hash{String => Object>}] plan The partition plan
    #
    # @return true if each volume group has a supplying physical
    # volume.

    def internalCheckVolgroups(plan)
      plan = deep_copy(plan)
      sane = true
      # Check that each volume group has at least
      # one physical volume
      volGroups = internalGetAvailableVolgroups(plan)
      physDrives = internalGetAvailablePhysicalDrives(plan)
      Builtins.foreach(volGroups) do |volGroup|
        # check all physical drives for physical volumes
        # "feeding" current volume group
        found = false
        volGroupName = removePrefix(
          Ops.get_string(volGroup, "device", "xyz"),
          "/dev/"
        )
        Builtins.foreach(physDrives) do |physDrive|
          Builtins.foreach(Ops.get_list(physDrive, "partitions", [])) do |part|
            if volGroupName == Ops.get_string(part, "lvm_group", "zxy")
              found = true
              Builtins.y2milestone(
                "Found 'feeding' partition for volume group '%1'",
                volGroupName
              )
            end
          end
        end
        # if no feeder (PV) was found for current volume group
        # the next instructions taints result
        if !found
          Popup.Error(
            Builtins.sformat(
              _(
                "Volume group '%1' must have at least one physical volume. Provide one."
              ),
              volGroupName
            )
          )
        end
        sane = found
      end
      sane
    end

    # Check the sanity of the partition plan.
    #
    # @param [Array<Hash{String => Object>}] plan The partition plan
    #
    # @return true if plan is sane, false otherwise.
    def internalCheckSanity(plan)
      internalCheckVolgroups(plan)
    end

    # Create tree structure from AutoPartPlan
    def updateTree
      Builtins.y2milestone("entering updateTree")
      # remember selected tree item
      item = currentTreeItem
      tree = []
      # let tree widget reflect AutoPartPlan
      Builtins.foreach(@AutoPartPlan) do |drive|
        tree = Builtins.add(tree, AutoinstDrive.createTree(drive))
      end
      Builtins.y2milestone("Setting tree: '%1'", tree)
      if Ops.greater_than(Builtins.size(@AutoPartPlan), 0)
        setTree(tree)
        # restore former selection
        if nil != item && "" != item
          Builtins.y2milestone("reselecting item '%1' after tree update.", item)
          selectTreeItem(item)
        else
          firstDrive = internalGetDriveByListIndex(@AutoPartPlan, 0)
          selectTreeItem(AutoinstDrive.getNodeReference(firstDrive))
        end
      end

      nil
    end

    # Create a partition plan for the calling client
    # @return [Array] partition plan
    def ReadHelper
      devicegraph = Y2Storage::StorageManager.instance.probed
      profile = Y2Storage::AutoinstProfile::PartitioningSection.new_from_storage(devicegraph)
      profile.to_hashes
    end

    # PUBLIC INTERFACE

    # INTER FACE TO CONF TREE

    # Return summary of configuration
    # @return  [String] configuration summary dialog
    def Summary
      summary = ""
      summary = Summary.AddHeader(summary, _("Drives"))
      if @AutoPartPlan.empty?
        summary = Summary.AddLine(summary,
          _("Not yet cloned."))
      else
        # We are counting harddisks only (type CT_DISK)
        num = @AutoPartPlan.count { |drive| drive["type"] == :CT_DISK }
        summary = Summary.AddLine(
          summary,
          (n_("%s drive in total", "%s drives in total", num) % num)
        )
        summary = Summary.OpenList(summary)
        Builtins.foreach(@AutoPartPlan) do |drive|
          driveDesc = AutoinstDrive.getNodeName(drive, true)
          summary = Summary.AddListItem(summary, driveDesc)
          summary = Summary.OpenList(summary)
          Builtins.foreach(Ops.get_list(drive, "partitions", [])) do |part|
            summary = Summary.AddListItem(
              summary,
              AutoinstPartition.getPartitionDescription(part, true)
            )
          end
          summary = Summary.CloseList(summary)
          summary = Summary.AddNewLine(summary)
        end
        summary = Summary.CloseList(summary)
      end
      summary
    end

    # Get all the configuration from a map.
    # When called by inst_auto<module name> (preparing autoinstallation data)
    # the list may be empty.
    # @param [Array<Hash>] settings a list  [...]
    # @return  [Boolean] success
    def Import(settings)
      log.info("entering Import with #{settings.inspect}")
      # index settings
      @AutoPartPlan = settings.map.with_index { |d, i| d.merge("_id" => i) }
      # set default value
      @AutoPartPlan.each do |d|
        d["initialize"] = false unless d.key?("initialize")
      end
      true
    end

    def Read
      Import(ReadHelper())
    end

    # Dump the settings to a map, for autoinstallation use.
    # @return [Array]
    def Export
      log.info("entering Export with #{@AutoPartPlan.inspect}")
      drives = deep_copy(@AutoPartPlan)
      drives.each { |d| d.delete("_id") }

      # Adding skipped devices to partitioning section.
      # These devices will not be taken in the AutoYaSt configuration file
      # but will be added to the skip_list in order not regarding it while
      # next installation. (bnc#989392)
      unless @skipped_devices.empty?
        skip_device = {}
        skip_device["initialize"] = true
        skip_device["skip_list"] = @skipped_devices.collect do |dev|
          { "skip_key" => "device", "skip_value" => dev }
        end
        drives << skip_device
      end

      drives
    end

    def Reset
      @AutoPartPlan = []

      nil
    end

    # =============================
    #  General info about the plan
    # =============================

    # Get a list of mount point strings that are currently not in use
    #
    # @return List of currently unused mount points

    def getAvailableMountPoints
      usedMountPoints = internalGetUsedMountPoints(@AutoPartPlan)
      availableMountPoints = Builtins.filter(
        AutoinstPartition.getDefaultMountPoints
      ) { |mp| !Builtins.contains(usedMountPoints, mp) }
      Builtins.y2milestone("Available mount points: '%1'", availableMountPoints)
      deep_copy(availableMountPoints)
    end

    # Get the next free/unused mount point string.
    #
    # @return Next free mount point string.

    def getNextAvailableMountPoint
      availableMountPoints = getAvailableMountPoints
      Ops.get(availableMountPoints, 0, "")
    end
    # Get list of (device) names of volume groups present in the
    # plan.
    #
    # @return List of currently present volume group device names.

    def getAvailableVolgroups
      Builtins.maplist(internalGetAvailableVolgroups(@AutoPartPlan)) do |vg|
        Ops.get_string(vg, "device", "not-set")
      end
    end

    # Triggers a sanity check over the current state of the plan.
    #
    # @return true if plan is sane, false otherwise.

    def checkSanity
      internalCheckSanity(@AutoPartPlan)
    end

    # ==================
    #  DRIVE OPERATIONS
    # ==================

    # Get drive identified by id (as in the tree node strings
    # ["device_1"]). Caution: this is not the same as the index (see
    # getDriveByListIndex()), as the id never changes, independent of
    # the position of this drive in the list.
    #
    # @param [Fixnum] which ID of drive to acquire.
    #
    # @return The drive identified by ID if a drive with that ID
    # exists; and empty list otherwise.

    def getDrive(which)
      internalGetDrive(@AutoPartPlan, which)
    end

    # Get drive identified by its position in the partition plan.
    #
    # @param [Fixnum] index The list index identifying the drive.
    #
    # @return The drive identifyied by index, the empty list
    # otherwise.

    def getDriveByListIndex(index)
      internalGetDriveByListIndex(@AutoPartPlan, index)
    end

    # Returns the number of drives present in plan.
    #
    # @return Number of drives present in plan.

    def getDriveCount
      Builtins.size(@AutoPartPlan)
    end

    # Remove drive identified by drive ID from the partition plan.
    # Selects preceeding drive, if deleted drive was last in list.
    # Otherwise the successor is selected.
    #
    # @param [Fixnum] which ID of drive to delete.

    def removeDrive(which)
      # most of the complexity here is due to correct
      # reselection behaviour after a drive has been deleted
      removalDriveIdx = internalGetListIndex(@AutoPartPlan, which)
      oldDriveCount = getDriveCount
      @AutoPartPlan = internalRemoveDrive(@AutoPartPlan, which)
      drive = if Ops.greater_than(oldDriveCount, 1) &&
          removalDriveIdx == Ops.subtract(oldDriveCount, 1)
        # lowest drive in tree was deleted, select predecessor
        getDriveByListIndex(Ops.subtract(removalDriveIdx, 1))
      else
        # a top or middle one was deleted, select successor
        getDriveByListIndex(removalDriveIdx)
      end
      selectTreeItem(AutoinstDrive.getNodeReference(drive))
      updateTree

      nil
    end

    # Add a new drive to the plan.
    #
    # @param [Hash{String => Object}] drive The new drive to add.

    def addDrive(drive)
      drive = deep_copy(drive)
      @AutoPartPlan = internalAddDrive(@AutoPartPlan, drive)
      updateTree
      deep_copy(drive)
    end

    # Update a drive in the plan. If the drive didn't exist in the
    # first place nothing happens (use add in that case).
    #
    # @param drive [Hash{String => Object}] The drive to be updated.
    def updateDrive(drive)
      drive = deep_copy(drive)
      @AutoPartPlan = internalUpdateDrive(@AutoPartPlan, drive)
      updateTree

      nil
    end

    # ======================
    #  PARTITION OPERATIONS
    # ======================

    # Get partition identified by partitionIdx on drive with
    # specified id.
    #
    # Note: Partition index refers to the position of the partition in
    # the list on the drive and thus is subject to invalidation on any
    # modifications of that list.
    #
    # @param [Fixnum] driveId The integer id of the drive containing the
    # partition.
    # @param [Fixnum] partitionIdx Index of partition to get.
    #
    # @return The partition if driveId and partitionIdx were valid,
    # an empty map otherwise.

    def getPartition(driveId, partitionIdx)
      currentDrive = getDrive(driveId)
      Builtins.y2milestone("Loaded drive '%1'", currentDrive)
      AutoinstDrive.getPartition(currentDrive, partitionIdx)
    end

    # Update a partition on a drive.
    #
    # Note: Partition index refers to the position of the partition in
    # the list on the drive and thus is subject to invalidation on any
    # modifications of that list.
    #
    # @param [Fixnum] driveId The integer id of the drive containing the
    # partition.
    # @param [Fixnum] partitionIdx Index of the partition to update.
    # @param [Hash{String => Object}] partition The updated/new partition.
    #
    # @return true if update was successfull, false otherwise.

    def updatePartition(driveId, partitionIdx, partition)
      partition = deep_copy(partition)
      drive = getDrive(driveId)
      if AutoinstDrive.isDrive(drive)
        drive = AutoinstDrive.updatePartition(drive, partitionIdx, partition)
        updateDrive(drive)
        return true
      else
        Builtins.y2milestone(
          "Could not update partition. Invalid driveId: '%1'",
          driveId
        )
        return false
      end
    end

    # Create a new partition on a drive.
    #
    # The new partition is assinged a default mountpoint and a default
    # parition number, or, in case its parent drive is a LVM, a volume
    # name.
    #
    # @param [Fixnum] driveId The drive to create the new partition on.
    #
    # @return The index of the newly created partition.

    def newPartition(driveId)
      newPartitionIndex = -1
      parentDrive = getDrive(driveId)
      if AutoinstDrive.isDrive(parentDrive)
        mountPoint = getNextAvailableMountPoint
        newPartitionNumber = AutoinstDrive.getNextAvailablePartitionNumber(
          parentDrive
        )
        newPart = AutoinstPartition.new(mountPoint)
        newPart = AutoinstPartition.set(
          newPart,
          "partition_nr",
          newPartitionNumber
        )
        if :CT_DISK != Ops.get_symbol(parentDrive, "type", :Empty)
          newPart = AutoinstPartition.set(
            newPart,
            "lv_name",
            AutoinstPartition.getLVNameFor(mountPoint)
          )
        end
        parentDrive = AutoinstDrive.addPartition(parentDrive, newPart)
        newPartitionIndex = Ops.subtract(
          AutoinstDrive.getPartitionCount(parentDrive),
          1
        )
        updateDrive(parentDrive)
      else
        Builtins.y2error(
          "Cannot create new partition on invalid drive with id '%1'.",
          driveId
        )
      end
      newPartitionIndex
    end

    # Delete a partition on a drive.
    #
    # @param [Fixnum] driveId Drive containing the partition to be deleted.
    # @param [Fixnum] partitionIdx The partition index identifying the parition
    # to be deleted.
    #
    # @return true if removal was successfull, false otherwise.

    def deletePartition(driveId, partitionIdx)
      drive = getDrive(driveId)
      if AutoinstDrive.isDrive(drive)
        oldPartitionCount = AutoinstDrive.getPartitionCount(drive)
        drive = AutoinstDrive.removePartition(drive, partitionIdx)
        updateDrive(drive)
        if AutoinstDrive.getPartitionCount(drive) == 0
          # if no partitions are left select parent drive
          selectTreeItem(AutoinstDrive.getNodeReference(drive))
        elsif partitionIdx == Ops.subtract(oldPartitionCount, 1)
          # the removed partition was the last one
          selectTreeItem(
            Ops.add(
              Ops.add(Ops.add("part_", Builtins.tostring(driveId)), "_"),
              Builtins.tostring(Ops.subtract(partitionIdx, 1))
            )
          )
        end
        return true
      else
        Builtins.y2error(
          "Cannot delete partition on invalid drive with index '%1'.",
          driveId
        )
        return false
      end
    end

    publish function: :SetModified, type: "void ()"
    publish function: :GetModified, type: "boolean ()"
    publish function: :updateTree, type: "void ()"
    publish function: :Summary, type: "string ()"
    publish function: :Import, type: "boolean (list <map>)"
    publish function: :Read, type: "boolean ()"
    publish function: :Export, type: "list <map> ()"
    publish function: :Reset, type: "void ()"
    publish function: :getAvailableMountPoints, type: "list <string> ()"
    publish function: :getNextAvailableMountPoint, type: "string ()"
    publish function: :getAvailableVolgroups, type: "list <string> ()"
    publish function: :checkSanity, type: "boolean ()"
    publish function: :getDrive, type: "map <string, any> (integer)"
    publish function: :getDriveByListIndex, type: "map <string, any> (integer)"
    publish function: :getDriveCount, type: "integer ()"
    publish function: :removeDrive, type: "void (integer)"
    publish function: :addDrive, type: "map <string, any> (map <string, any>)"
    publish function: :updateDrive, type: "void (map <string, any>)"
    publish function: :getPartition, type: "map <string, any> (integer, integer)"
    publish function: :updatePartition, type: "boolean (integer, integer, map <string, any>)"
    publish function: :newPartition, type: "integer (integer)"
    publish function: :deletePartition, type: "boolean (integer, integer)"
  end

  AutoinstPartPlan = AutoinstPartPlanClass.new
  AutoinstPartPlan.main
end
