# encoding: utf-8

# File:	modules/AutoinstCommon.ycp
# Package:	Auto-installation/Partition
# Summary:	Module representing a partitioning plan
# Author:	Sven Schober (sschober@suse.de)
#
# $Id: AutoinstPartPlan.ycp 2813 2008-06-12 13:52:30Z sschober $
require "yast"

module Yast
  class AutoinstPartPlanClass < Module
    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.include self, "autoinstall/autopart.rb"
      Yast.include self, "autoinstall/types.rb"
      Yast.include self, "autoinstall/common.rb"
      Yast.include self, "autoinstall/tree.rb"

      Yast.import "AutoinstCommon"
      Yast.import "AutoinstDrive"
      Yast.import "AutoinstPartition"
      Yast.import "Summary"
      Yast.import "Popup"
      Yast.import "Mode"
      Yast.import "StorageDevices"
      Yast.import "Storage"
      Yast.import "Partitions"
      Yast.import "FileSystems"
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
      result = []
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
    # @param [Array<Hash{String => Object>}] plan The partition plan.
    #
    # @return Partition plan containing only volgroups.

    def internalGetAvailableVolgroups(plan)
      plan = deep_copy(plan)
      result = []
      result = Builtins.filter(@AutoPartPlan) do |curDrive|
        Ops.get_symbol(curDrive, "type", :CT_DISK) != :CT_DISK
      end
      deep_copy(result)
    end

    # Get a list of all physical (not volgroup) drives.
    #
    # @param [Array<Hash{String => Object>}] plan The partition plan.
    #
    # @return Partition plan containing only physical drives.

    def internalGetAvailablePhysicalDrives(plan)
      plan = deep_copy(plan)
      result = []
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
    #	- check that each VG has at least one PV
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
      plan = deep_copy(plan)
      sane = true
      sane = internalCheckVolgroups(plan)
      # ...
      sane
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
      Mode.SetMode("normal")
      StorageDevices.InitDone
      _StorageMap = Builtins.eval(Storage.GetTargetMap)
      FileSystems.read_default_subvol_from_target

      _StorageMap = _StorageMap.select do |d, p|
        ok = true
        if( d == "/dev/nfs" && p["partitions"] != nil)
          # Checking if /dev/nfs container has a root partition.
          # If yes, it can be taken for the plan (bnc#986124)
          ok = p["partitions"].any?{ |part| part["mount"] == "/" }
        end
	if( ok && p.fetch("partitions", []).size==0 )
	  ok = p.fetch("used_by_type",:UB_NONE)==:UB_LVM
	end
	ok
      end
      Builtins.y2milestone("Storagemap %1", _StorageMap)

      drives = Builtins.maplist(_StorageMap) do |k, v|
        partitions = []
        winp = []
        no_format_list = [65, 6, 222]
        no_create_list = [222]
        usepartitions = []
        cyl_size = Ops.get_integer(v, "cyl_size", 0)
        no_create = false
        Builtins.foreach(Ops.get_list(v, "partitions", [])) do |pe|
          next if Ops.get_symbol(pe, "type", :x) == :extended
          new_pe = {}

          # Handling nfs root partitions. (bnc#986124)
          if pe["type"] == :nfs
            new_pe["type"] = pe["type"]
            new_pe["device"] = pe["device"]
            new_pe["mount"] = pe["mount"]
            new_pe["fstopt"] = pe["fstopt"]
            partitions << new_pe
          end
          next if pe["type"] == :nfs

          Ops.set(new_pe, "create", true)
          new_pe["ignore_fstab"] = pe["ignore_fstab"] if pe.has_key?("ignore_fstab")
          skipwin = false
          if Builtins.haskey(pe, "enc_type")
            Ops.set(
              new_pe,
              "enc_type",
              Ops.get_symbol(pe, "enc_type", :twofish)
            )
            Ops.set(new_pe, "crypt_key", "ENTER KEY HERE")
            Ops.set(new_pe, "loop_fs", true)
            Ops.set(new_pe, "crypt_fs", true)
          end
          if Builtins.haskey(pe, "fsid")
            fsid = Ops.get_integer(pe, "fsid", 131)
            wintypes = Builtins.union(
              Partitions.fsid_wintypes,
              Partitions.fsid_dostypes
            )
            allwin = Builtins.union(wintypes, Partitions.fsid_ntfstypes)
            if Builtins.contains(allwin, fsid) &&
                !Builtins.issubstring(Ops.get_string(pe, "mount", ""), "/boot") &&
                  !Ops.get_boolean(pe, "boot", false)
              #                    if (contains(allwin, fsid) && ! issubstring(pe["mount"]:"", "/boot") )
              Builtins.y2debug("Windows partitions found: %1", fsid)
              winp = Builtins.add(winp, Ops.get_integer(pe, "nr", 0))
              skipwin = true
              no_create = true if Ops.greater_than(Builtins.size(partitions), 0)
            end
            if Builtins.contains(allwin, fsid) &&
                Builtins.issubstring(Ops.get_string(pe, "mount", ""), "/boot")
              Ops.set(new_pe, "partition_id", 259)
            else
              Ops.set(new_pe, "partition_id", Ops.get_integer(pe, "fsid", 131))
            end
            if Builtins.contains(no_format_list, Ops.get_integer(pe, "fsid", 0))
              Ops.set(new_pe, "format", false)
            end
            if Builtins.contains(no_create_list, Ops.get_integer(pe, "fsid", 0))
              Ops.set(new_pe, "create", false)
            end
          end
          # Consider the partition type when dealing with 'msdos' partition tables (bsc#1091415)
          if Builtins.haskey(pe, "type") && v["label"] == "msdos"
            Ops.set(new_pe, "partition_type", pe["type"].to_s)
          end
          if Builtins.haskey(pe, "region") &&
              Ops.get_boolean(new_pe, "create", true) == true
            # don't clone the exact region.
            # I don't see any benefit in cloning that strict.
            #new_pe["region"] = pe["region"]:[];
            #                    new_pe["size"] = sformat("%1", pe["size_k"]:0*1024);
            if Ops.less_than(
                Ops.subtract(
                  Ops.multiply(Ops.get_integer(pe, "size_k", 0), 1024),
                  cyl_size
                ),
                cyl_size
              ) # bnc#415005
              Ops.set(new_pe, "size", Builtins.sformat("%1", cyl_size))
            else
              Ops.set(
                new_pe,
                "size",
                Builtins.sformat(
                  "%1",
                  Ops.subtract(
                    Ops.multiply(Ops.get_integer(pe, "size_k", 0), 1024),
                    cyl_size
                  )
                )
              )
            end # one cylinder buffer for #262535
          end
          if Builtins.haskey(pe, "label")
            Ops.set(new_pe, "label", Ops.get_string(pe, "label", ""))
          end
          if Builtins.haskey(pe, "mountby")
            Ops.set(new_pe, "mountby", Ops.get_symbol(pe, "mountby", :nomb))
          end
          if Builtins.haskey(pe, "fstopt")
            Ops.set(new_pe, "fstopt", Ops.get_string(pe, "fstopt", "defaults"))
          end
          # LVM Group
          if Builtins.haskey(pe, "used_by_type") &&
              Ops.get_symbol(pe, "used_by_type", :nothing) == :UB_LVM
            Ops.set(
              new_pe,
              "lvm_group",
              Builtins.substring(Ops.get_string(pe, "used_by_device", ""), 5)
            )
          end
          # LV
          if Ops.get_symbol(pe, "type", :unknown) == :lvm
            Ops.set(new_pe, "lv_name", Ops.get_string(pe, "name", ""))
            Ops.set(
              new_pe,
              "size",
              Builtins.sformat(
                "%1",
                Ops.multiply(Ops.get_integer(pe, "size_k", 0), 1024)
              )
            )
            if Builtins.haskey(pe, "stripes")
              Ops.set(new_pe, "stripes", Ops.get_integer(pe, "stripes", 0))
              Ops.set(
                new_pe,
                "stripesize",
                Ops.get_integer(pe, "stripesize", 4)
              )
            end
          end
          if Builtins.haskey(pe, "used_by_type") &&
              Ops.get_symbol(pe, "used_by_type", :nothing) == :UB_MD
            Ops.set(
              new_pe,
              "raid_name",
              Ops.get_string(pe, "used_by_device", "")
            )
          end
          # Used Filesystem
          # Raid devices get the filesystem lying on them as
          # detected_fs!
          if Builtins.haskey(pe, "used_fs") &&
              Ops.get_integer(pe, "fsid", 0) != 253
            Ops.set(new_pe, "filesystem", Ops.get_symbol(pe, "used_fs") do
              Partitions.DefaultFs
            end)
            Ops.set(
              new_pe,
              "format",
              Ops.get_boolean(
                new_pe,
                "format",
                Ops.get_boolean(pe, "format", true)
              )
            )
          end
          if Ops.get_boolean(new_pe, "format", false) &&
              !Builtins.isempty(Ops.get_string(pe, "mkfs_options", ""))
            Ops.set(
              new_pe,
              "mkfs_options",
              Ops.get_string(pe, "mkfs_options", "")
            )
          end
          # Subvolumes
          # Save possibly existing subvolumes
          if !pe.fetch("subvol", []).empty?
            defsub = ""
            if !FileSystems.default_subvol.empty?
              defsub = FileSystems.default_subvol + "/"
            end
            new_pe["subvolumes"] = pe.fetch("subvol", []).map { |s| export_subvolume(s, defsub) }

            Ops.set(
              new_pe,
              "subvolumes",
              Builtins.filter(Ops.get_list(new_pe, "subvolumes", [])) do |s|
                !Builtins.isempty(s)
              end
            )
          end
          # Handle thin stuff
          Ops.set(new_pe, "pool", true) if Ops.get_boolean(pe, "pool", false)
          if !Builtins.isempty(Ops.get_string(pe, "used_pool", ""))
            Ops.set(new_pe, "used_pool", Ops.get_string(pe, "used_pool", ""))
          end
          # if the filesystem is unknown, we have detected_fs and no longer used_fs
          # don't know why yast2-storage is having two keys for that.
          # maybe it would be even okay to look only for "detected_fs" to set format to false
          # bnc#542331 (L3: AutoYaST clone module fails to set format option for non-formatted logical volumes)
          if Ops.get_symbol(pe, "detected_fs", :known) == :unknown
            Ops.set(new_pe, "format", false)
          end
          if Builtins.haskey(pe, "nr") &&
              Ops.get_symbol(pe, "type", :unknown) != :lvm
            if !skipwin
              Builtins.y2debug(
                "Adding partition to be used: %1",
                Ops.get_integer(pe, "nr", 0)
              )
              usepartitions = Builtins.add(
                usepartitions,
                Ops.get_integer(pe, "nr", 0)
              )
            end
            Ops.set(new_pe, "partition_nr", Ops.get_integer(pe, "nr", 0))
          end
          if Ops.get_string(pe, "mount", "") != ""
            Ops.set(new_pe, "mount", Ops.get_string(pe, "mount", ""))
          end
          if k == "/dev/md"
            raid_options = {}
            raid_options["persistent_superblock"] = pe.fetch("persistent_superblock",false)
            raid_options["raid_type"] = pe.fetch("raid_type", "raid0")
            raid_options["device_order"] = pe.fetch("devices",[])
	    if pe["device"].start_with?("/dev/md/")
	      raid_options["raid_name"] = pe["device"]
	    end
            new_pe["raid_options"]=raid_options
          end
          if !skipwin && Ops.get_integer(new_pe, "partition_id", 0) != 15
            partitions = Builtins.add(partitions, new_pe)
          end
        end
        # don't create partitions that are between windows partitions
        # they must exist
        drive = {}
        Ops.set(drive, "type", Ops.get_symbol(v, "type", :CT_DISK))
        # A disklabel for the container of NFS mounts is useless.
        Ops.set(drive, "disklabel", Ops.get_string(v, "label", "msdos")) unless drive["type"] == :CT_NFS
        if no_create
          partitions = Builtins.maplist(
            Convert.convert(partitions, :from => "list", :to => "list <map>")
          ) do |m|
            Ops.set(m, "create", false)
            deep_copy(m)
          end
        end
	if( v.fetch("used_by_type",:UB_NONE)==:UB_LVM && partitions.empty? )
	  partitions = [{ "partition_nr" => 0, "create" => false,
	                  "lvm_group" => v.fetch("used_by_device", "")[5..-1],
			  "size" => "max" }]
	  Builtins.y2milestone( "lvm full disk v:%1", v )
	  Builtins.y2milestone( "lvm full disk p:%1", partitions )
	end
        Ops.set(drive, "partitions", partitions)
        if Arch.s390 && Ops.get_symbol(v, "type", :CT_DISK) == :CT_DISK
          Ops.set(
            drive,
            "device",
            Ops.add("/dev/disk/by-path/", Ops.get_string(v, "udev_path", k))
          )
          Builtins.y2milestone(
            "s390 found. Setting device to by-path: %1",
            Ops.get_string(drive, "device", "")
          )
        else
          Ops.set(drive, "device", k)
        end
        if Ops.get_symbol(v, "type", :CT_UNKNOWN) == :CT_LVM
          Ops.set(
            drive,
            "pesize",
            Builtins.sformat(
              "%1M",
              Ops.divide(Ops.get_integer(v, "pesize", 1), 1024 * 1024)
            )
          )
          Ops.set(drive, "type", :CT_LVM)
        end
        if Builtins.haskey(v, "lvm2") && Ops.get_boolean(v, "lvm2", false)
          Ops.set(drive, "lvm2", true)
        end
        if Ops.greater_than(Builtins.size(partitions), 0)
          if Builtins.size(winp) == 0
            Ops.set(drive, "use", "all")
          else
            up = []
            Builtins.foreach(usepartitions) do |i|
              up = Builtins.add(up, Builtins.sformat("%1", i))
            end
            Ops.set(drive, "use", Builtins.mergestring(up, ","))
          end
        end
        deep_copy(drive)
      end

      drives = Builtins.filter(
        Convert.convert(drives, :from => "list", :to => "list <map>")
      ) do |v|
        keep = false
        Builtins.foreach(Ops.get_list(v, "partitions", [])) do |p|
          if Ops.get_string(p, "mount", "") != "" ||
              Builtins.haskey(p, "lvm_group") ||
              Builtins.haskey(p, "raid_name")
            keep = true
            raise Break
          end
        end
        keep
      end

      Mode.SetMode("autoinst_config")
      deep_copy(drives)
    end


    # PUBLIC INTERFACE

    # INTER FACE TO CONF TREE

    # Return summary of configuration
    # @return  [String] configuration summary dialog
    def Summary
      summary = ""
      summary = Summary.AddHeader(summary, _("Drives"))
      unless @AutoPartPlan.empty?
        # We are counting harddisks only (type CT_DISK)
        num = @AutoPartPlan.count{|drive| drive["type"] == :CT_DISK }
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
      else
        summary = Summary.AddLine( summary,
          _("Not yet cloned.")
        )
      end
      summary
    end

    # Get all the configuration from a map.
    # When called by inst_auto<module name> (preparing autoinstallation data)
    # the list may be empty.
    # @param [Array<Hash>] settings a list	[...]
    # @return	[Boolean] success
    def Import(settings)
      settings = deep_copy(settings)
      Builtins.y2milestone("entering Import with %1", settings)

      # Filter out all tmpfs that have not been defined by the user.
      # User created entries are defined in the fstab only.
      tmpfs_devices = settings.select { |device| device["type"] == :CT_TMPFS }
      tmpfs_devices.each do |device|
        if device["partitions"]
          device["partitions"].delete_if { |partition| partition["ignore_fstab"] }
        end
      end

      # It makes no sense to have tmpfs dummy containers which have no partitions.
      # E.g. the partitions have been filtered because they have not been defined
      # by the user.
      # (bnc#887318)
      settings.delete_if { |device|
        device["type"] == :CT_TMPFS && (!device["partitions"] || device["partitions"].empty? )
      }

      @AutoPartPlan = []
      _IgnoreTypes = [:CT_BTRFS]
      Builtins.foreach(settings) do |drive|
        if !Builtins.contains(
            _IgnoreTypes,
            Ops.get_symbol(drive, "type", :CT_DISK)
          )
          newDrive = AutoinstDrive.parseDrive(drive)
          if AutoinstDrive.isDrive(newDrive)
            @AutoPartPlan = internalAddDrive(@AutoPartPlan, newDrive)
          else
            Builtins.y2error("Couldn't construct DriveT from '%1'", drive)
          end
        else
          Builtins.y2milestone(
            "Ignoring Container type '%1'",
            Ops.get_symbol(drive, "type", :CT_DISK)
          )
        end
      end
      true
    end

    def Read
      Import(
        Convert.convert(ReadHelper(), :from => "list", :to => "list <map>")
      )
    end

    # Dump the settings to a map, for autoinstallation use.
    # @return [Array]
    def Export
      Builtins.y2milestone("entering Export")
      drives = Builtins.maplist(@AutoPartPlan) do |drive|
        AutoinstDrive.Export(drive)
      end

      clean_drives = Builtins.maplist(drives) do |d|
        p = Builtins.maplist(Ops.get_list(d, "partitions", [])) do |part|
          part = Builtins.remove(part, "fsid") if Builtins.haskey(part, "fsid")
          if Builtins.haskey(part, "used_fs")
            part = Builtins.remove(part, "used_fs")
          end
          deep_copy(part)
        end
        Ops.set(d, "partitions", p)
        # this is to delete the dummy "auto" filled in by UI
        if Builtins.haskey(d, "device") &&
            Ops.get_string(d, "device", "") == "auto"
          d = Builtins.remove(d, "device")
          Builtins.y2milestone("device 'auto' dropped")
        end
        deep_copy(d)
      end

      deep_copy(clean_drives)
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
      availableMountPoints = []
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
      drive = {}
      if Ops.greater_than(oldDriveCount, 1) &&
          removalDriveIdx == Ops.subtract(oldDriveCount, 1)
        # lowest drive in tree was deleted, select predecessor
        drive = getDriveByListIndex(Ops.subtract(removalDriveIdx, 1))
      else
        # a top or middle one was deleted, select successor
        drive = getDriveByListIndex(removalDriveIdx)
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
    # @param The drive to update.

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

    publish :function => :SetModified, :type => "void ()"
    publish :function => :GetModified, :type => "boolean ()"
    publish :function => :updateTree, :type => "void ()"
    publish :function => :Summary, :type => "string ()"
    publish :function => :Import, :type => "boolean (list <map>)"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :Export, :type => "list <map> ()"
    publish :function => :Reset, :type => "void ()"
    publish :function => :getAvailableMountPoints, :type => "list <string> ()"
    publish :function => :getNextAvailableMountPoint, :type => "string ()"
    publish :function => :getAvailableVolgroups, :type => "list <string> ()"
    publish :function => :checkSanity, :type => "boolean ()"
    publish :function => :getDrive, :type => "map <string, any> (integer)"
    publish :function => :getDriveByListIndex, :type => "map <string, any> (integer)"
    publish :function => :getDriveCount, :type => "integer ()"
    publish :function => :removeDrive, :type => "void (integer)"
    publish :function => :addDrive, :type => "map <string, any> (map <string, any>)"
    publish :function => :updateDrive, :type => "void (map <string, any>)"
    publish :function => :getPartition, :type => "map <string, any> (integer, integer)"
    publish :function => :updatePartition, :type => "boolean (integer, integer, map <string, any>)"
    publish :function => :newPartition, :type => "integer (integer)"
    publish :function => :deletePartition, :type => "boolean (integer, integer)"
  end

  AutoinstPartPlan = AutoinstPartPlanClass.new
  AutoinstPartPlan.main
end
