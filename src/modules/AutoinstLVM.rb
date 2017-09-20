# encoding: utf-8

# File:    modules/AutoinstLVM.ycp
# Module:    Auto-Installation
# Summary:    LVM
# Authors:    Anas Nashif <nashif@suse.de>

require "yast"

module Yast
  class AutoinstLVMClass < Module

    include Yast::Logger

    # Report shrinking if it will be bigger than about 20 MBytes.
    REPORT_DISK_SHRINKING_LIMIT = 20000

    def main
      textdomain "autoinst"

      Yast.import "Storage"
      Yast.import "Report"
      Yast.import "Partitions"
      Yast.import "FileSystems"
      Yast.import "AutoinstStorage"
      Yast.import "Label"

      Yast.include self, "partitioning/lvm_lv_lib.rb"


      @ExistingLVM = {}

      @ExistingVGs = []

      @keepLVM = {}

      # LVM map as imported from Profile
      @lvm = {}


      # useless
      #    boolean pvs_on_unconfigured = false;


      # temporary copy of variable from Storage
      # map <string, map> targetMap = $[];

      # temporary copy of variable from Storage
      @targetMap = {}

      @old_available = false
      AutoinstLVM()
    end

    # Constructer
    def AutoinstLVM
      nil
    end


    # Initialize
    # @return [void]
    def Init
      Builtins.y2milestone("entering Init")
      Builtins.y2milestone("AutoTargetMap is %1", AutoinstStorage.AutoTargetMap)
      @lvm = Builtins.filter(AutoinstStorage.AutoTargetMap) do |k, v|
        Ops.get_symbol(v, "type", :CT_UNKNOWN) == :CT_LVM
      end

      # check for existing VM
      @targetMap = Storage.GetTargetMap
      Builtins.y2milestone("GetTargetMap returns %1", @targetMap)
      @ExistingLVM = Builtins.filter(Storage.GetTargetMap) do |k, v|
        Ops.get_symbol(v, "type", :CT_UNKNOWN) == :CT_LVM
      end
      if Builtins.haskey(@ExistingLVM, "/dev/evms")
        @ExistingLVM = Builtins.remove(@ExistingLVM, "/dev/evms")
      end
      @ExistingVGs = Builtins.maplist(@ExistingLVM) do |d, g|
        Builtins.substring(d, 5)
      end

      # we say keep all LVs where the keep_unknown_lv is set
      Builtins.foreach(@ExistingLVM) do |k, v|
        vgname = Ops.get_string(v, "name", "")
        Builtins.foreach(Ops.get_list(v, "partitions", [])) do |p|
          if Ops.get_boolean(
              @lvm,
              [Ops.add("/dev/", vgname), "keep_unknown_lv"],
              false
            ) == true
            Ops.set(
              @keepLVM,
              vgname,
              Builtins.add(
                Ops.get(@keepLVM, vgname, []),
                Ops.get_string(p, "lv_name", "")
              )
            )
          end
        end
      end

      # look for VGs to reuse
      Builtins.foreach(AutoinstStorage.AutoTargetMap) do |k, v|
        Builtins.foreach(Ops.get_list(v, "partitions", [])) do |p|
          if Builtins.haskey(p, "lvm_group") &&
              Ops.get_boolean(p, "create", true) == false &&
              Ops.get_boolean(p, "format", true) == false
            if !Builtins.contains(
                @ExistingVGs,
                Ops.get_string(p, "lvm_group", "x")
              )
              Report.Error(
                Builtins.sformat(
                  _(
                    "Cannot reuse volume group %1. The volume group does not exist."
                  ),
                  Ops.get_string(p, "lvm_group", "x")
                )
              )
            end
            atm = deep_copy(AutoinstStorage.AutoTargetMap)
            Builtins.foreach(
              Ops.get_list(
                atm,
                [
                  Ops.add("/dev/", Ops.get_string(p, "lvm_group", "x")),
                  "partitions"
                ],
                []
              )
            ) do |vg_p|
              lvm_group = Ops.get_string(p, "lvm_group", "x")
              # we know the LV now. So remove it from the keep-list for now
              Ops.set(
                @keepLVM,
                lvm_group,
                Builtins.filter(Ops.get(@keepLVM, lvm_group, [])) do |v2|
                  v2 != Ops.get_string(vg_p, "lv_name", "")
                end
              )
              if Ops.get_boolean(vg_p, "create", true) == false
                Ops.set(
                  @keepLVM,
                  lvm_group,
                  Builtins.add(
                    Ops.get(@keepLVM, lvm_group, []),
                    Ops.get_string(vg_p, "lv_name", "")
                  )
                )
              end
            end
          end
        end
      end

      Builtins.y2milestone("Existing VGs: %1", @ExistingVGs)
      Builtins.y2milestone("Existing LVM: %1", @ExistingLVM)
      Builtins.y2milestone("keep LVM: %1", @keepLVM)

      # FIXME
      Builtins.foreach(@ExistingVGs) do |v|
        dev = Builtins.sformat("/dev/%1", v)
        if Ops.greater_than(
            Builtins.size(Ops.get_list(@ExistingLVM, [dev, "partitions"], [])),
            0
          )
          @old_available = true
        end
      end


      # Process data
      @lvm = Builtins.mapmap(@lvm) do |device, disk|
        Ops.set(
          disk,
          "pesize",
          AutoinstStorage.humanStringToByte(
            Ops.get_string(disk, "pesize", "4M"),
            true
          )
        )
        vgname = Builtins.substring(device, 5)
        Ops.set(
          disk,
          "partitions",
          Builtins.maplist(Ops.get_list(disk, "partitions", [])) do |lv|
            lvsize_str = Ops.get_string(lv, "size", "")
            mount_point = Ops.get_string(lv, "mount", "")
            lvsize = 0
            vgsize = Ops.multiply(
              Ops.get_integer(@targetMap, [device, "size_k"], 0),
              1024
            )
            if (lvsize_str == "auto" || lvsize_str == "suspend") &&
                mount_point == "swap"
              Builtins.y2milestone(
                "swap slot size: %1",
                Ops.multiply(Ops.divide(vgsize, 1024), 1024)
              )
              lvsize = Ops.multiply(
                1024 * 1024,
                Partitions.SwapSizeMb(
                  Ops.divide(vgsize, 1024 * 1024),
                  lvsize_str == "suspend"
                )
              )
            elsif lvsize_str != ""
              lvsize = AutoinstStorage.humanStringToByte(lvsize_str, true)
            end
            Ops.set(lv, "size_k", Ops.divide(lvsize, 1024))
            Ops.set(lv, "type", :lvm)
            Ops.set(lv, "name", Ops.get_string(lv, "lv_name", ""))
            deep_copy(lv)
          end
        )
        { device => disk }
      end

      true
    end

    # Delete possible partitions
    def remove_possible_volumes(vgname)
      Builtins.y2milestone("Deleting possible VGs and LVs")
      return true if @ExistingLVM == {}

      vg = Ops.get(@ExistingLVM, Ops.add("/dev/", vgname), {})
      lvs = Ops.get_list(vg, "partitions", [])
      Builtins.y2milestone("Existing LVs: %1", lvs)

      Builtins.foreach(lvs) do |lv|
        if !Builtins.contains(
            Ops.get(@keepLVM, vgname, []),
            Ops.get_string(lv, "name", "")
          )
          Storage.DeleteDevice(
            Ops.add(
              Ops.add(Ops.add("/dev/", vgname), "/"),
              Ops.get_string(lv, "name", "")
            )
          )
        end
      end

      if !Builtins.haskey(@keepLVM, vgname) &&
          Ops.get(@ExistingLVM, Ops.add("/dev/", vgname), {}) != {}
        Storage.DeleteLvmVg(vgname)
      end

      true
    end

    # Return only those PVs on disks touched by the control file, dont add PVs of
    # unconfigured disks.
    # @param string volume group name
    # @return [Array] existing PVs
    def get_existing_pvs(vgname)
      Builtins.y2milestone("entering get_existing_pvs with %1", vgname)

      usedBy = :UB_LVM

      # all possible PVs on all available devices
      all_possible_pvs = Builtins.filter(get_possible_pvs(Storage.GetTargetMap)) do |part|
        (Ops.get_string(part, "used_by_device", "") == Ops.add("/dev/", vgname) &&
          Ops.get_symbol(part, "used_by_type", :UB_NONE) == usedBy ||
          Ops.get_symbol(part, "used_by_type", :UB_NONE) == :UB_NONE) &&
          !Ops.get_boolean(part, "delete", false)
      end

      Builtins.y2milestone("all pvs= %1", all_possible_pvs)

      # FIXME
      deep_copy(all_possible_pvs)
    end

    # Write LVM Configuration
    # @return [Boolean] true on success
    def Write
      Builtins.y2milestone("entering Write")
      Storage.SetZeroNewPartitions(AutoinstStorage.ZeroNewPartitions)

      lvm_vgs = get_vgs(@targetMap)
      current_vg = ""

      error = false

      Builtins.foreach(@lvm) do |device, volume_group|
        Builtins.y2milestone("volume_group is %1", volume_group)
        use = Ops.get_string(volume_group, "use", "none")
        lvm2 = Ops.get_boolean(volume_group, "lvm2", true)
        lvm_string = lvm2 ? "lvm2" : "lvm"
        vgname = Builtins.substring(device, 5)
        current_vg = vgname
        new_pvs = get_existing_pvs(vgname)
        pesize = Ops.get_integer(volume_group, "pesize", 1)
        if Ops.get_boolean(volume_group, "prefer_remove", false)
          remove_possible_volumes(vgname)
        end
        if Builtins.size(Ops.get_list(volume_group, "keep_lv", [])) == 0
          ret = Storage.CreateLvmVg(
            vgname,
            Ops.get_integer(volume_group, "pesize", 4194304),
            lvm2
          )
          current_vg = vgname
          Builtins.y2milestone("CreateLvmVg returns %1", ret)
          @targetMap = Storage.GetTargetMap
          Builtins.y2milestone("Storage::GetTargetMap returns %1", @targetMap)
          lvm_vgs = get_vgs(@targetMap)
        end
        new_pvs_devices = Builtins.maplist(new_pvs) do |pv|
          Ops.get_string(pv, "device", "")
        end
        Builtins.y2milestone("Existing PVs: %1", new_pvs)
        atm = deep_copy(AutoinstStorage.AutoTargetMap)
        smallest_physical = 0
        Builtins.foreach(new_pvs) do |pv|
          to_add = false
          if Ops.get_boolean(pv, "create", false)
            to_add = true
            # exclude partitions that are NOT supposed to be in the LVM
            Builtins.foreach(
              Ops.get_list(
                atm,
                [Ops.get_string(pv, "maindev", ""), "partitions"],
                []
              )
            ) do |atm_vol|
              if Ops.get_integer(pv, "nr", 0) ==
                  Ops.get_integer(atm_vol, "partition_nr", -1)
                if Ops.get_string(atm_vol, "lvm_group", "") != current_vg
                  Builtins.y2milestone("do not add %1", atm_vol)
                  to_add = false
                end
              end
            end
          else
            to_add = false
            # exclude partitions that are NOT supposed to be in the LVM
            Builtins.foreach(
              Ops.get_list(
                atm,
                [Ops.get_string(pv, "maindev", ""), "partitions"],
                []
              )
            ) do |atm_vol|
              if Ops.get_integer(pv, "nr", 0) ==
                  Ops.get_integer(atm_vol, "partition_nr", -1)
                if Ops.get_string(atm_vol, "lvm_group", "") == current_vg
                  Builtins.y2milestone("add %1", atm_vol)
                  to_add = true
                end
              end
            end
          end
          if to_add
            Builtins.y2milestone(
              "addPhysicalVolume %1 , %2",
              Ops.get_string(pv, "device", ""),
              current_vg
            )
            if smallest_physical == 0 ||
                Ops.less_than(
                  Ops.get_integer(pv, "size_k", 0),
                  smallest_physical
                )
              smallest_physical = Ops.get_integer(pv, "size_k", 0)
            end
            addPhysicalVolume(
              @targetMap,
              Ops.get_string(pv, "device", ""),
              current_vg
            )
          end
        end
        # calculating the "max" for logical volume
        tmp_tm = Storage.GetTargetMap
        freeSpace = 0
        buffer = 0
        freeSpace = Ops.get_integer(tmp_tm, [device, "size_k"], 0)
        buffer = Ops.get_integer(tmp_tm, [device, "cyl_size"], 0)
        buffer = Ops.divide(Ops.multiply(buffer, 2), 1024)
        max_counter = 0
        Ops.set(
          volume_group,
          "partitions",
          Builtins.maplist(Ops.get_list(volume_group, "partitions", [])) do |lv|
            s = AutoinstStorage.humanStringToByte(
              Ops.get_string(lv, "size", "10000"),
              true
            )
            if Ops.less_or_equal(s, 100) && Ops.greater_than(s, 0)
              # we assume percentage for this lv
              integer_k = Ops.divide(
                Ops.multiply(
                  freeSpace,
                  Builtins.tointeger(Ops.get_string(lv, "size", "0"))
                ),
                100
              )
              Ops.set(lv, "size_k", integer_k)
              Builtins.y2milestone(
                "percentage for lv %1. Size_k is %2",
                lv,
                integer_k
              )
            elsif (Ops.get_string(lv, "size", "") == "max" || Ops.get_string(lv, "size", "") == "auto") &&
                Ops.less_or_equal(Ops.get_integer(lv, "stripes", 0), 1)
              # "auto" size does not make sense here. But we are switching to the "max" behaviour in order
              # not to produce an error and to evaluate other useable settings. (bnc#962034)
              Report.Warning( "Option \"auto\" is not supported with LVM. Taking \"max\" option instead.") if lv["size"] == "auto"
              max_counter = Ops.add(max_counter, 1)
            end
            deep_copy(lv)
          end
        )
        partitions = []
        Builtins.foreach(Ops.get_list(volume_group, "partitions", [])) do |lv|
          size_k = lv.fetch("size_k", 0)
          if (size_k > freeSpace)
            lv["size_k"] = freeSpace
            Builtins.y2milestone("Requested partition size of %s on \"%s\" will be reduced to "\
                "%s in order to fit on disk." %
                [size_k, lv["mount"], freeSpace])
            if (size_k - freeSpace) > REPORT_DISK_SHRINKING_LIMIT
              Report.Warning(_("Requested partition size of %s on \"%s\" will be reduced to "\
                "%s in order to fit on disk.") %
                [Storage.KByteToHumanString(size_k), lv["mount"], Storage.KByteToHumanString(freeSpace)])
            end
          end
          freeSpace = Ops.subtract(freeSpace, Ops.get_integer(lv, "size_k", 0))
          Builtins.y2milestone("freeSpace = %1", freeSpace)
          partitions << lv
        end
        volume_group["partitions"] = partitions
        freeSpace = Ops.subtract(freeSpace, buffer) # that's a buffer for rounding errors with cylinder boundaries
        Builtins.foreach(Ops.get_list(volume_group, "partitions", [])) do |lv|
          if Ops.get_integer(lv, "size_k", 0) == 0 &&
              Ops.greater_than(freeSpace, 0)
            # if "max" calculation is turned on for the LV
            if Ops.greater_than(Ops.get_integer(lv, "stripes", 0), 1)
              Ops.set(
                lv,
                "size_k",
                Ops.multiply(
                  smallest_physical,
                  Ops.get_integer(lv, "stripes", 1)
                )
              )
              Ops.set(
                lv,
                "size",
                Builtins.sformat(
                  "%1K",
                  Ops.multiply(
                    smallest_physical,
                    Ops.get_integer(lv, "stripes", 1)
                  )
                )
              )
              freeSpace = Ops.subtract(
                freeSpace,
                Ops.get_integer(lv, "size_k", 0)
              )
              smallest_physical = 0
              Builtins.y2milestone(
                "max-config for striped LV found. Setting size to %1",
                Ops.get_string(lv, "size", "0")
              )
            else
              Ops.set(lv, "size_k", Ops.divide(freeSpace, max_counter))
              Ops.set(lv, "size", Builtins.sformat("%1K", freeSpace))
            end
          end
          Builtins.y2milestone(
            "size_k before rounding %1",
            Ops.get_integer(lv, "size_k", 0)
          )
          Ops.set(
            lv,
            "size_k",
            Ops.divide(
              Ops.multiply(
                Ops.divide(
                  Ops.multiply(Ops.get_integer(lv, "size_k", 0), 1024),
                  pesize
                ),
                pesize
              ),
              1024
            )
          ) # rounding
          Builtins.y2milestone(
            "size_k after rounding %1",
            Ops.get_integer(lv, "size_k", 0)
          )
          lvlist = Ops.get_list(@ExistingLVM, [device, "partitions"], [])
          if Builtins.contains(
              Ops.get(@keepLVM, vgname, []),
              Ops.get_string(lv, "lv_name", "")
            )
            lvtokeep = Builtins.filter(lvlist) do |p|
              Ops.get_string(p, "nr", "") == Ops.get_string(lv, "lv_name", "")
            end
            this_lv = Ops.get(lvtokeep, 0, {})

            Builtins.y2milestone("Keeping LV: %1", this_lv)
            Builtins.y2milestone("lv = %1", lv)

            Ops.set(
              lv,
              "device",
              Ops.add(
                Ops.add(Ops.add("/dev/", vgname), "/"),
                Ops.get_string(lv, "lv_name", "")
              )
            )
            Ops.set(lv, "used_fs", Ops.get_symbol(this_lv, "used_fs") do
              Partitions.DefaultFs
            end)

            lvret = {}
            if Ops.get_boolean(lv, "resize", false)
              reslv = {
                "create"  => false,
                "region"  => Ops.get_list(lv, "region", []),
                "fsid"    => 142,
                "lv_size" => Ops.get_integer(lv, "lv_size", 0),
                "fstype"  => "LV",
                "nr"      => Ops.get_string(lv, "nr", ""),
                "mount"   => Ops.get_string(lv, "mount", ""),
                "used_fs" => Ops.get_symbol(this_lv, "used_fs") do
                  Partitions.DefaultFs
                end,
                "format"  => Ops.get_boolean(lv, "format", false),
                "device"  => Ops.get_string(lv, "device", "")
              }
              Ops.set(reslv, "changed_size", true)
              Storage.ResizeVolume(
                Ops.add(
                  Ops.add(Ops.add("/dev/", current_vg), "/"),
                  Ops.get_string(lv, "name", "")
                ),
                Ops.add("/dev/", current_vg),
                Ops.divide(Ops.get_integer(lv, "lv_size", 0), 1024)
              )
            else
              Storage.ChangeVolumeProperties(lv)
            end
            @targetMap = Convert.convert(
              Ops.get(lvret, "targets", @targetMap),
              :from => "any",
              :to   => "map <string, map>"
            )
          elsif Ops.get_boolean(lv, "create", true)
            Ops.set(lv, "used_fs", Ops.get_symbol(lv, "filesystem") do
              Partitions.DefaultFs
            end)
            lv = AutoinstStorage.AddFilesysData(lv, lv)
            Ops.set(lv, "create", true)
            Ops.set(lv, "format", Ops.get_boolean(lv, "format", true))
            Ops.set(
              lv,
              "device",
              Ops.add(
                Ops.add(Ops.add("/dev/", current_vg), "/"),
                Ops.get_string(lv, "name", "")
              )
            )
            Builtins.y2milestone(
              "calling addLogicalVolume with lv = %1 and current_vg = %2",
              lv,
              current_vg
            )
            addLogicalVolume(lv, current_vg)
            @targetMap = Storage.GetTargetMap
            Builtins.y2milestone("Storage::GetTargetMap returns %1", @targetMap)
          end
        end
      end
      Builtins.y2milestone("targetmap: %1", @targetMap)

      AutoinstStorage.AutoTargetMap.each do |device, data|
        target_map = Storage.GetTargetMap()
        if target_map.has_key?(device) && data["type"] == :CT_LVM
          if data["enable_snapshots"] && target_map[device].has_key?("partitions")
            root_partition = target_map[device]["partitions"].find do
              |p| p["mount"] == "/" && p["used_fs"] == :btrfs
            end
            if root_partition
              log.info("Enabling snapshots for \"/\"; root_partition #{root_partition}")
              Storage.SetUserdata(root_partition["device"], { "/" => "snapshots" })
            end
          end
        end
      end

      true
    end

    publish :variable => :ExistingLVM, :type => "map <string, map>"
    publish :variable => :ExistingVGs, :type => "list <string>"
    publish :variable => :keepLVM, :type => "map <string, list <string>>"
    publish :variable => :lvm, :type => "map <string, map>"
    publish :function => :AutoinstLVM, :type => "void ()"
    publish :function => :Init, :type => "boolean ()"
    publish :function => :get_existing_pvs, :type => "list <map> (string)"
    publish :function => :Write, :type => "boolean ()"
  end

  AutoinstLVM = AutoinstLVMClass.new
  AutoinstLVM.main
end
