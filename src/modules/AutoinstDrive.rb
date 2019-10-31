# encoding: utf-8

# File:  modules/AutoinstCommon.ycp
# Package:  Auto-installation/Partition
# Summary:  Drive related functions module
# Author:  Sven Schober (sschober@suse.de)
#
# $Id: AutoinstDrive.ycp 2813 2008-06-12 13:52:30Z sschober $
require "yast"

module Yast
  class AutoinstDriveClass < Module
    def main
      Yast.import "UI"

      Yast.include self, "autoinstall/types.rb"
      Yast.include self, "autoinstall/common.rb"
      Yast.include self, "autoinstall/tree.rb"

      Yast.import "AutoinstCommon"
      Yast.import "AutoinstPartition"
      Yast.import "Mode"

      textdomain "autoinst"

      # Structure of a drive, or volume group.
      @fields = {
        "_id"        => 0, # Internal id; won't appear in XML
        "device"     => "", # device name (e.g. "/dev/hda")
        "initialize" => true, # wipe out disk
        "partitions" => [], # list of partitions on this drive
        "type"       => :CT_DISK, # type of drive, see diskTypes below
        "use"        => :all, # `all, `linux, `free, or list of partition numbers to use
        "pesize"     => "",
        "disklabel"  => "msdos" # type of partition table (msdos or gpt)
      } # size of physical extents (currently no GUI support for this setting)

      # Every drive created gets an id.
      @_id = 0
      # List of allowed disk/drive types
      @diskTypes = [:CT_DISK, :CT_LVM, :CT_MD, :CT_NFS, :CT_TMPFS]
    end

    # Determine if type is a valid drive type.
    #
    # @param [Symbol] type symbol supposedly identifying a drive type.
    #
    # @return true of type is valid false otherwise.
    def isValidDiskType(type)
      Builtins.contains(@diskTypes, type)
    end

    # Set field on drive to value. Convenience wrapper for generic setter.
    #
    # @param [Hash{String => Object}] drive drive to be updated.
    # @param [String] field field to be set.
    # @param [Object] value value to be stored.
    def set(drive, field, value)
      drive = deep_copy(drive)
      value = deep_copy(value)
      AutoinstCommon.set(@fields, drive, field, value)
    end

    # Constructor
    # Constructs a new drive of type type with "device" set to name.
    #
    # @param [String] name device name of new drive.
    # @param [Symbol] type type of new drive.
    def new(name, type)
      if !isValidDiskType(type)
        Builtins.y2warning(
          "Invalid disk type: '%1'. Defaulting to CT_DISK",
          type
        )
        type = :CT_DISK
      end
      result = set(set(set(@fields, "device", name), "_id", @_id), "type", type)
      @_id = Ops.add(@_id, 1)
      deep_copy(result)
    end

    # Convenience wrappers for more general object predicates
    def isDrive(drive)
      drive = deep_copy(drive)
      AutoinstCommon.isValidObject(@fields, drive)
    end

    def isField(field)
      AutoinstCommon.isValidField(@fields, field)
    end

    def hasValidType(field, value)
      value = deep_copy(value)
      AutoinstCommon.hasValidType(@fields, field, value)
    end

    def areEqual(d1, d2)
      d1 = deep_copy(d1)
      d2 = deep_copy(d2)
      AutoinstCommon.areEqual(d1, d2)
    end

    # Construct reference to drive for use in tree. The references
    # are of the form:
    #  "{ drive, volgroup }_<id>",
    #  e.g. "drive_1", or "volgroup_3"
    #
    # @param drive [Hash{String => Object}] drive drive to create the reference for.
    # @return [String] reference
    def getNodeReference(drive)
      drive = deep_copy(drive)
      dev_id = Ops.get_integer(drive, "_id", 999)
      ref = "drive_"
      ref = "volgroup_" if Ops.get_symbol(drive, "type", :CT_DISK) != :CT_DISK
      Ops.add(ref, Builtins.tostring(dev_id))
    end

    # Construct node name for display in tree.
    #
    # Constructed names are of the form:
    #  "<device name> - { drive, volgroup }
    #
    # @param drive [Hash{String => Object}] drive to create node name for
    # @param enableHTML [Boolean] Use HTML tags
    # @return the newly created node name
    def getNodeName(drive, enableHTML)
      drive = deep_copy(drive)
      nodeName = Ops.get_string(drive, "device", "")
      nodeName = Builtins.sformat("<b>%1</b>", nodeName) if enableHTML
      description = _(" - Drive")
      driveType = Ops.get_symbol(drive, "type", :CT_DISK)
      if driveType != :CT_DISK
        # volume group
        description = _(" - Volume group")
        description = Ops.add(
          Ops.add(description, ", "),
          removePrefix(symbol2string(driveType), "CT_")
        )
      else
        # physical drive
        useTypeDesc = Ops.get_boolean(drive, "initialize", true) ? "initialize" : "reuse"
        description = if enableHTML
          Builtins.sformat(
            "%1 to be %2d",
            description,
            useTypeDesc
          )
        else
          Builtins.sformat("%1 , %2", description, useTypeDesc)
        end
      end
      Ops.add(nodeName, description)
    end
    # Create tree representation of drive for the tree widget.
    #
    # @param [Hash{String => Object}] drive Drive to process.
    #
    # @return A term representing an `Item with the current drive as
    # top node and all partitions as children.

    def createTree(drive)
      drive = deep_copy(drive)
      partitions = Ops.get_list(drive, "partitions", [])
      partitionTerms = []
      part_id = 0
      driveRef = getNodeReference(drive)

      if Ops.greater_than(Builtins.size(partitions), 0)
        Builtins.foreach(partitions) do |p|
          partitionTerms = Builtins.add(
            partitionTerms,
            AutoinstPartition.createTree(p, driveRef, part_id)
          )
          part_id = Ops.add(part_id, 1)
        end
      end
      createTreeNode(driveRef, getNodeName(drive, false), partitionTerms)
    end

    # Get partition identified by idx from drive.
    #
    # CAUTION: Indexes may be invalidated by modifications of the
    # partition list on a drive.
    #

    def getPartition(drive, idx)
      drive = deep_copy(drive)
      result = {}
      if isDrive(drive)
        partList = Ops.get_list(drive, "partitions", [])
        result = Ops.get(partList, idx, {})
      else
        Builtins.y2error("Invalid drive: '%1'.", drive)
      end
      deep_copy(result)
    end

    # Returns number of partitions on spcified drive.
    #
    # @param [Hash{String => Object}] drive The drive to inspect.
    #
    # @return Number of partitions on drive.

    def getPartitionCount(drive)
      drive = deep_copy(drive)
      Builtins.size(Ops.get_list(drive, "partitions", []))
    end

    # Return lowest partition number not already in use.
    #
    # @param [Hash{String => Object}] drive The drive to process.
    #
    # @return Lowest free partition number.

    def getNextAvailablePartitionNumber(drive)
      drive = deep_copy(drive)
      usedPartitionNumbers = []
      # gather all used numbers
      Builtins.foreach(Ops.get_list(drive, "partitions", [])) do |part|
        partitionNumber = Ops.get_integer(part, "partition_nr", 999)
        if partitionNumber != 999
          usedPartitionNumbers = Builtins.add(
            usedPartitionNumbers,
            partitionNumber
          )
        end
      end
      newPartitionNumber = 1
      # then look for the lowest number not used
      while Builtins.contains(usedPartitionNumbers, newPartitionNumber)
        newPartitionNumber = Ops.add(newPartitionNumber, 1)
      end
      newPartitionNumber
    end

    # Mutators

    # Add a partition to a drive.
    #
    # @param [Hash{String => Object}] drive Drive to be added to.
    # @param [Hash{String => Object}] partition Partition to be added.
    #
    # @return Drive containing the new parition.

    def addPartition(drive, partition)
      drive = deep_copy(drive)
      partition = deep_copy(partition)
      if AutoinstPartition.isPartition(partition)
        partitionList = Ops.get_list(drive, "partitions", [])
        # TODO: which constraints are on inserting?
        partitionList = Builtins.add(partitionList, partition)

        return Builtins.add(drive, "partitions", partitionList)
      else
        Builtins.y2error("No valid partition: '%1'", partition)
      end

      nil
    end

    # Update partition on drive.
    #
    # @param [Hash{String => Object}] drive Drive containing parition to be updated.
    # @param [Fixnum] idx Integer identifying the partition to be updated (list
    # index).
    # @param [Hash{String => Object}] partition New/Updated partition.
    #
    # @return Drive containing updated partition.

    def updatePartition(drive, idx, partition)
      drive = deep_copy(drive)
      partition = deep_copy(partition)
      if isDrive(drive)
        if AutoinstPartition.isPartition(partition)
          partitionList = Ops.get_list(drive, "partitions", [])
          if Ops.less_than(idx, Builtins.size(partitionList))
            Ops.set(partitionList, idx, partition)
            return Builtins.add(drive, "partitions", partitionList)
          else
            Builtins.y2error(
              "Index '%1' out of bounds. Drive has only '%2' partitions.",
              idx,
              Builtins.size(partitionList)
            )
          end
        else
          Builtins.y2error("No valid partition: '%1'.", partition)
        end
      else
        Builtins.y2error("No valid drive '%1'.", drive)
      end
      deep_copy(drive)
    end

    # Remove partition from drive.
    #
    # @param [Hash{String => Object}] drive Drive containing the partition to be deleted.
    # @param [Fixnum] idx Integer identifying partition to be deleted (list
    # index).
    #
    # @return Drive missing the deleted partition.

    def removePartition(drive, idx)
      drive = deep_copy(drive)
      if isDrive(drive)
        partitionList = Ops.get_list(drive, "partitions", [])
        if Ops.less_than(idx, Builtins.size(partitionList))
          partitionList = Builtins.remove(partitionList, idx)
          return Builtins.add(drive, "partitions", partitionList)
        else
          Builtins.y2error(
            "Cannot remove partition '%1', index out of bounds. Drive has only '%2' partitions",
            idx,
            Builtins.size(partitionList)
          )
        end
      else
        Builtins.y2error(
          "Cannot remove partition '%1' from invalid drive '%2'.",
          idx,
          drive
        )
      end

      nil
    end

    publish function: :set, type: "map <string, any> (map <string, any>, string, any)"
    publish function: :new, type: "map <string, any> (string, symbol)"
    publish function: :isDrive, type: "boolean (map <string, any>)"
    publish function: :isField, type: "boolean (string)"
    publish function: :hasValidType, type: "boolean (string, any)"
    publish function: :areEqual, type: "boolean (map <string, any>, map <string, any>)"
    publish function: :getNodeReference, type: "string (map <string, any>)"
    publish function: :getNodeName, type: "string (map <string, any>, boolean)"
    publish function: :createTree, type: "term (map <string, any>)"
    publish function: :getPartition, type: "map <string, any> (map <string, any>, integer)"
    publish function: :getPartitionCount, type: "integer (map <string, any>)"
    publish function: :getNextAvailablePartitionNumber, type: "integer (map <string, any>)"
    publish function: :addPartition, type: "map <string, any> " \
      "(map <string, any>, map <string, any>)"
    publish function: :updatePartition, type: "map <string, any> " \
      "(map <string, any>, integer, map <string, any>)"
    publish function: :removePartition, type: "map <string, any> (map <string, any>, integer)"
  end

  AutoinstDrive = AutoinstDriveClass.new
  AutoinstDrive.main
end
