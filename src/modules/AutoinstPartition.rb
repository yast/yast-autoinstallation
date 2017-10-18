# encoding: utf-8

# File:	modules/AutoinstCommon.ycp
# Package:	Auto-installation/Partition
# Summary:	Partition related functions module
# Author:	Sven Schober (sschober@suse.de)
#
# $Id: AutoinstPartition.ycp 2813 2008-06-12 13:52:30Z sschober $
require "yast"

module Yast
  class AutoinstPartitionClass < Module
    def main
      Yast.import "UI"

      Yast.include self, "autoinstall/types.rb"
      Yast.include self, "autoinstall/common.rb"
      Yast.include self, "autoinstall/tree.rb"

      Yast.import "AutoinstCommon"
      Yast.import "Partitions"
      Yast.import "FileSystems"
      Yast.import "Storage"

      textdomain "autoinst"

      # defines data structur of a partition
      # provides types for type checking
      @fields = {
        "crypt"        => "",
        "crypt_fs"     => false,
        "crypt_key"    => "",
        "create"       => true,
        "mount"        => "/",
        "fstopt"       => "",
        "label"        => "",
        "loop_fs"      => false,
        "uuid"         => "",
        "size"         => "10G",
        "format"       => true,
        "filesystem"   => Partitions.DefaultFs,
        "mkfs_options" => "",
        "partition_nr" => 1,
        "partition_id" => 131,
        "mountby"      => :device,
        "resize"       => false,
        "lv_name"      => "",
        "stripes"      => 1,
        "stripesize"   => 4,
        "lvm_group"    => "",
        "raid_name"    => "",
        "raid_type"    => "",
        "raid_options" => {},
        "subvolumes"   => [],
        "pool"         => false,
        "used_pool"    => ""
      }

      @allfs = {}

      @defaultMountPoints = [
        "/",
        "/boot",
        "/home",
        "/usr",
        "/usr/local",
        "swap",
        "/tmp"
      ]
      @allUnits = ["Byte", "MB", "GB", "%", "max"]
      @maxPartitionNumber = 999
      AutoinstPartition()
    end

    def AutoinstPartition
      @allfs = FileSystems.GetAllFileSystems(true, true, "")

      nil
    end
    # Convenience wrappers for more general object predicates
    def isPartition(partition)
      partition = deep_copy(partition)
      AutoinstCommon.isValidObject(@fields, partition)
    end
    def isField(field)
      AutoinstCommon.isValidField(@fields, field)
    end
    def hasValidType(field, value)
      value = deep_copy(value)
      AutoinstCommon.hasValidType(@fields, field, value)
    end
    def areEqual(p1, p2)
      p1 = deep_copy(p1)
      p2 = deep_copy(p2)
      AutoinstCommon.areEqual(p1, p2)
    end

    # Convenience wrapper for setter
    def set(partition, field, value)
      partition = deep_copy(partition)
      value = deep_copy(value)
      AutoinstCommon.set(@fields, partition, field, value)
    end


    # Constructor
    def new(mp)
      set(@fields, "mount", mp)
    end

    def getNodeReference(parentRef, partitionIndex)
      # e.g.: parentRef = "drive:0"
      driveID = Builtins.substring(
        parentRef,
        Ops.add(Builtins.findfirstof(parentRef, "_"), 1)
      )
      idx = Builtins.tostring(partitionIndex)
      Builtins.sformat("part_%1_%2", driveID, idx)
    end

    def getPartitionDescription(p, enableHTML)
      p = deep_copy(p)
      part_desc = Ops.get_string(p, "mount", "")
      if "" == part_desc
        if p["lvm_group"] && !p["lvm_group"].empty?
          part_desc = p["lvm_group"]
          if enableHTML
            part_desc = "Physical volume for volume group &lt;<b>#{part_desc}</b>&gt;"
          else
            part_desc = "<#{part_desc}>"
          end
        else
          part_desc = "Physical volume"
        end
      else
        if enableHTML
          part_desc = Builtins.sformat("<b>%1</b> partition", part_desc)
        end
      end
      if Ops.get_boolean(p, "create", false)
        if p["size"] &&  !p["size"].empty?
          part_desc += " with #{Storage.ByteToHumanString(p["size"].to_i)}"
        end
      else
        if Ops.get_boolean(p, "resize", false)
          part_desc = Builtins.sformat(
            "%1 resize part.%2 to %3",
            part_desc,
            Ops.get_integer(p, "partition_nr", 999),
            Storage.ByteToHumanString(p["size"].to_i)
          )
        else
          part_desc = Builtins.sformat(
            "%1 reuse part. %2",
            part_desc,
            Ops.get_integer(p, "partition_nr", 999)
          )
        end
      end
      part_desc = Builtins.sformat(
        "%1,%2",
        part_desc,
        Partitions.FsIdToString(Ops.get_integer(p, "partition_id", 131))
      )

      fs = Ops.get(@allfs, Ops.get_symbol(p, "filesystem", :nothing), {})
      fs_name = Ops.get_string(fs, :name, "")
      part_desc = Builtins.sformat("%1,%2", part_desc, fs_name) if "" != fs_name

      if Ops.greater_than(Builtins.size(Ops.get_list(p, "region", [])), 0)
        reg_info = Builtins.sformat(
          "%1 - %2",
          Ops.get_integer(p, ["region", 0], 0),
          Ops.get_integer(p, ["region", 1], 0)
        )
        part_desc = Builtins.sformat("%1,%2", part_desc, reg_info)
      end
      part_desc
    end


    def createTree(p, parentRef, idx)
      p = deep_copy(p)
      part_desc = getPartitionDescription(p, false)
      createTreeNode(getNodeReference(parentRef, idx), part_desc, [])
    end


    def getTokenizedSize(part)
      part = deep_copy(part)
      encodedSize = Ops.get_string(part, "size", "")
      # regex tokenizes size strings of the liking:
      # "1000", "10KB", "1 GB" and "max"
      Builtins.regexptokenize(encodedSize, "([0-9]*)s*([A-Za-z%]*)")
    end


    def getSize(part)
      part = deep_copy(part)
      tokenizedSize = getTokenizedSize(part)
      sizeString = Ops.get(tokenizedSize, 0, "0")
      unitString = Ops.get(tokenizedSize, 1, "")
      if "auto" == unitString || "max" == unitString || "" == sizeString
        sizeString = "0"
      end
      Builtins.tointeger(sizeString)
    end

    def getUnit(part)
      part = deep_copy(part)
      if "max" == Ops.get_string(part, "size", "") ||
          "auto" == Ops.get_string(part, "size", "")
        return Ops.get_string(part, "size", "")
      else
        return Ops.get(getTokenizedSize(part), 1, "")
      end
    end

    def getFormat(part)
      part = deep_copy(part)
      Ops.get_boolean(part, "format", false)
    end

    def isPartOfVolgroup(part)
      part = deep_copy(part)
      Ops.get_string(part, "lvm_group", "") != ""
    end

    def getFileSystem(part)
      part = deep_copy(part)
      Ops.get_symbol(part, "filesystem", :Empty)
    end

    def parsePartition(part)
      part = deep_copy(part)
      newPart = new(Ops.get_string(part, "mount", ""))
      newPart = set(
        newPart,
        "mountby",
        Ops.get_symbol(part, "mountby", :device)
      )
      if Builtins.haskey(part, "label")
        newPart = set(newPart, "label", Ops.get_string(part, "label", ""))
      end
      newPart = set(newPart, "create", Ops.get_boolean(part, "create", true))
      newPart = set(newPart, "crypt", Ops.get_string(part, "crypt", ""))
      newPart = set(
        newPart,
        "crypt_fs",
        Ops.get_boolean(part, "crypt_fs", false)
      )
      newPart = set(newPart, "crypt_key", Ops.get_string(part, "crypt_key", ""))
      newPart = set(newPart, "format", Ops.get_boolean(part, "format", true))
      if Builtins.haskey(part, "filesystem")
        newPart = set(
          newPart,
          "filesystem",
          Ops.get_symbol(part, "filesystem", :Empty)
        )
        newPart = set(newPart, "format", true)
      elsif Mode.config
        # We are in the autoyast configuration mode. So if the parsed
        # system partitions do not have a filesystem entry (E.G. Raids)
        # we are not using the default entry (Partitions.DefaultFs).
        newPart["filesystem"] = :Empty
      end
      if Ops.get_boolean(newPart, "format", false) &&
          !Builtins.isempty(Ops.get_string(part, "mkfs_options", ""))
        Ops.set(
          newPart,
          "mkfs_options",
          Ops.get_string(part, "mkfs_options", "")
        )
      else
        newPart = Builtins.remove(newPart, "mkfs_options")
      end
      if !Builtins.isempty(Ops.get_list(part, "subvolumes", []))
        #Filtering out all snapper subvolumes
        newPart["subvolumes"] = part["subvolumes"].reject do |subvolume|
          subvolume["path"].start_with?(".snapshots")
        end
      elsif newPart["filesystem"] != :btrfs
        newPart = Builtins.remove(newPart, "subvolumes")
      end
      if !Builtins.isempty(Ops.get_string(part, "used_pool", ""))
        Ops.set(newPart, "used_pool", Ops.get_string(part, "used_pool", ""))
      else
        newPart = Builtins.remove(newPart, "used_pool")
      end
      if Ops.get_boolean(part, "pool", false)
        Ops.set(newPart, "pool", true)
      else
        newPart = Builtins.remove(newPart, "pool")
      end
      newPart = set(newPart, "loop_fs", Ops.get_boolean(part, "loop_fs", false))
      if part.has_key?("partition_id")
        newPart["partition_id"] = part["partition_id"]
      else
        #removing default entry
        newPart.delete("partition_id")
      end
      newPart = set(newPart, "size", Ops.get_string(part, "size", ""))
      newPart = set(newPart, "lv_name", Ops.get_string(part, "lv_name", ""))
      newPart = set(newPart, "lvm_group", Ops.get_string(part, "lvm_group", ""))
      newPart = set(newPart, "stripes", Ops.get_integer(part, "stripes", 1))
      # Set partition_nr too (if available) bnc#886808
      newPart["partition_nr"] = part["partition_nr"] if part["partition_nr"]
      newPart = set(
        newPart,
        "stripesize",
        Ops.get_integer(part, "stripesize", 4)
      )
      if Builtins.haskey(part, "fstopt")
        newPart = set(
          newPart,
          "fstopt",
          Ops.get_string(part, "fstopt", "defaults")
        )
      end
      if Ops.get_integer(part, "stripes", 1) == 1
        newPart = Builtins.remove(newPart, "stripes")
        newPart = Builtins.remove(newPart, "stripesize")
      end
      # partition_id enforcement
      if Builtins.haskey(part, "lvm_group")
        newPart = set(newPart, "partition_id", 142)
      elsif "swap" == Ops.get_string(newPart, "mount", "")
        newPart = set(newPart, "partition_id", 130)
      end
      if Builtins.haskey(part, "raid_name")
        newPart = set(
          newPart,
          "raid_name",
          Ops.get_string(part, "raid_name", "")
        )
      end
      if Builtins.haskey(part, "raid_options")
        newPart = set(
          newPart,
          "raid_options",
          Ops.get_map(part, "raid_options", {})
        )
      else
        newPart = Builtins.remove(newPart, "raid_options")
      end

      if part["partition_id"] == Partitions.fsid_bios_grub
        # GRUB_BIOS partitions must not be formated
        # with default filesystem btrfs. (bnc#876411)
        # The other deleted entries would be useless in that case.
        newPart.delete("filesystem")
        newPart.delete("format")
        newPart.delete("crypt_fs")
        newPart.delete("loop_fs")
        newPart.delete("mountby")
      end

      if part["filesystem"] == :tmpfs
        # remove not needed entries for TMPFS
        newPart.delete("partition_nr")
        newPart.delete("resize")
        newPart.delete("crypt_fs")
        newPart.delete("loop_fs")
      end

      deep_copy(newPart)
    end

    # Export filtering

    def exportPartition(part)
      part = deep_copy(part)
      # filter out empty string attributes
      result = {}
      result = Builtins.filter(part) do |key, value|
        if Ops.is_string?(value) && "" == value
          # false gets filtered out
          next false
        elsif Ops.is_symbol?(value) && :Empty == value
          next false
        else
          next true
        end
      end
      deep_copy(result)
    end


    def checkSanity(part)
      part = deep_copy(part)
      result = ""
      if "%" == getUnit(part) && 0 == getSize(part)
        result = Builtins.sformat(
          "%1You chose '%%' as size unit but did not provide a correct percentage value.\n",
          result
        )
      end
      # ...
      # other tests maybe
      # ...
      result
    end

    # "static" functions (don't need a PartitionT [this pointer])

    def getAllUnits
      deep_copy(@allUnits)
    end

    def getAllFileSystemTypes
      deep_copy(@allfs)
    end

    def getDefaultMountPoints
      deep_copy(@defaultMountPoints)
    end

    def getMaxPartitionNumber
      @maxPartitionNumber
    end


    def getLVNameFor(mountPoint)
      result = removePrefix(mountPoint, "/")
      result = "root" if "" == result
      result
    end

    publish :function => :AutoinstPartition, :type => "void ()"
    publish :function => :isPartition, :type => "boolean (map <string, any>)"
    publish :function => :isField, :type => "boolean (string)"
    publish :function => :hasValidType, :type => "boolean (string, any)"
    publish :function => :areEqual, :type => "boolean (map <string, any>, map <string, any>)"
    publish :function => :set, :type => "map <string, any> (map <string, any>, string, any)"
    publish :function => :new, :type => "map <string, any> (string)"
    publish :function => :getNodeReference, :type => "string (string, integer)"
    publish :function => :getPartitionDescription, :type => "string (map <string, any>, boolean)"
    publish :function => :createTree, :type => "term (map <string, any>, string, integer)"
    publish :function => :getSize, :type => "integer (map <string, any>)"
    publish :function => :getUnit, :type => "string (map <string, any>)"
    publish :function => :getFormat, :type => "boolean (map <string, any>)"
    publish :function => :isPartOfVolgroup, :type => "boolean (map <string, any>)"
    publish :function => :getFileSystem, :type => "symbol (map <string, any>)"
    publish :function => :parsePartition, :type => "map <string, any> (map)"
    publish :function => :exportPartition, :type => "map <string, any> (map <string, any>)"
    publish :function => :checkSanity, :type => "string (map <string, any>)"
    publish :function => :getAllUnits, :type => "list <string> ()"
    publish :function => :getAllFileSystemTypes, :type => "map <symbol, map> ()"
    publish :function => :getDefaultMountPoints, :type => "list <string> ()"
    publish :function => :getMaxPartitionNumber, :type => "integer ()"
    publish :function => :getLVNameFor, :type => "string (string)"
  end

  AutoinstPartition = AutoinstPartitionClass.new
  AutoinstPartition.main
end
