# File:  modules/AutoinstCommon.ycp
# Package:  Auto-installation/Partition
# Summary:  Partition related functions module
# Author:  Sven Schober (sschober@suse.de)
#
# $Id: AutoinstPartition.ycp 2813 2008-06-12 13:52:30Z sschober $
require "yast"
require "y2storage"

module Yast
  class AutoinstPartitionClass < Module
    include Yast::Logger

    def main
      Yast.import "UI"

      Yast.include self, "autoinstall/types.rb"
      Yast.include self, "autoinstall/common.rb"
      Yast.include self, "autoinstall/tree.rb"

      Yast.import "AutoinstCommon"

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
        "filesystem"   => default_root_fs_type.to_sym,
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
      # The GetAllFileSystems of the old libstorag returns a hash with all kind of
      # information (even widgets!). Even more, every entry is a mashup of information
      # related to filesystems types and partition ids (both are often not clearly
      # distinguised in the old libstorage).
      #
      # This is a simplyfication with just some values.
      #
      # Moreover, this offers all the known filesystems, not necessarily the
      # supported ones.
      @allfs = Y2Storage::Filesystems::Type.all.each_with_object({}) do |type, hash|
        hash[type.to_sym] = { name: type.to_human_string, fsid: type.to_i }
      end
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
          part_desc = if enableHTML
            "Physical volume for volume group &lt;<b>#{part_desc}</b>&gt;"
          else
            "<#{part_desc}>"
          end
        else
          part_desc = "Physical volume"
        end
      elsif enableHTML
        part_desc = Builtins.sformat("<b>%1</b> partition", part_desc)
      end
      if Ops.get_boolean(p, "create", false)
        if p["size"] &&  !p["size"].empty?
          part_desc += " with #{Y2Storage::DiskSize.new(p["size"].to_i).to_human_string}"
        end
      else
        part_desc = if Ops.get_boolean(p, "resize", false)
          Builtins.sformat(
            "%1 resize part.%2 to %3",
            part_desc,
            Ops.get_integer(p, "partition_nr", 999),
            Y2Storage::DiskSize.new(p["size"].to_i).to_human_string
          )
        else
          Builtins.sformat(
            "%1 reuse part. %2",
            part_desc,
            Ops.get_integer(p, "partition_nr", 999)
          )
        end
      end
      part_desc = Builtins.sformat(
        "%1,%2",
        part_desc,
        Y2Storage::PartitionId.new_from_legacy(p.fetch("partition_id", 131)).to_s
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
      sizeString = "0" if "auto" == unitString || "max" == unitString || "" == sizeString
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

    publish function: :AutoinstPartition, type: "void ()"
    publish function: :isPartition, type: "boolean (map <string, any>)"
    publish function: :isField, type: "boolean (string)"
    publish function: :hasValidType, type: "boolean (string, any)"
    publish function: :areEqual, type: "boolean (map <string, any>, map <string, any>)"
    publish function: :set, type: "map <string, any> (map <string, any>, string, any)"
    publish function: :new, type: "map <string, any> (string)"
    publish function: :getNodeReference, type: "string (string, integer)"
    publish function: :getPartitionDescription, type: "string (map <string, any>, boolean)"
    publish function: :createTree, type: "term (map <string, any>, string, integer)"
    publish function: :getSize, type: "integer (map <string, any>)"
    publish function: :getUnit, type: "string (map <string, any>)"
    publish function: :getFormat, type: "boolean (map <string, any>)"
    publish function: :isPartOfVolgroup, type: "boolean (map <string, any>)"
    publish function: :getFileSystem, type: "symbol (map <string, any>)"
    publish function: :checkSanity, type: "string (map <string, any>)"
    publish function: :getAllUnits, type: "list <string> ()"
    publish function: :getAllFileSystemTypes, type: "map <symbol, map> ()"
    publish function: :getDefaultMountPoints, type: "list <string> ()"
    publish function: :getMaxPartitionNumber, type: "integer ()"
    publish function: :getLVNameFor, type: "string (string)"

  protected

    # Default filesystem for root ("/")
    #
    # @note Although this can be considered somehow generic enough to live in
    # Y2Storage::Filesystems::Type, it would first need several improvements.
    # First of all, it's not configurable by product (Btrfs doesn't have to
    # always be the default for "/") and it should accept any mount point (not
    # necessarily "/") as argument, which would introduce more problems (the
    # type for some mount points are debatable or product-based).
    #
    # @return [Y2Storage::Filesystems::Type]
    def default_root_fs_type
      # FIXME: see note in method description
      Y2Storage::Filesystems::Type::BTRFS
    end
  end

  AutoinstPartition = AutoinstPartitionClass.new
  AutoinstPartition.main
end
