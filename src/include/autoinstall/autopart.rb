# encoding: utf-8

# File:	include/autoinstall/autpart.rb
# Module:	Auto-Installation
# Summary:	Storage
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
module Yast
  module AutoinstallAutopartInclude
    def initialize_autoinstall_autopart(include_target)
      textdomain "autoinst"

      Yast.import "FileSystems"
      Yast.import "Partitions"
      Yast.import "Arch"

      @cur_mode = :free
      @cur_weight = -10000
      @cur_gap = {}
    end

    def AddSubvolData(st_map, xml_map)
      st_map = deep_copy(st_map)
      xml_map = deep_copy(xml_map)
      ret = deep_copy(st_map)
      if Ops.get_symbol(ret, "used_fs", :unknown) == :btrfs
        Builtins.y2milestone("AddSubvolData  st:%1", st_map)
        Builtins.y2milestone("AddSubvolData xml:%1", xml_map)
        if Builtins.haskey(xml_map, "subvolumes")
          sv_prep = ""
          if FileSystems.default_subvol != ""
            sv_prep = Ops.add(FileSystems.default_subvol, "/")
          end
          Ops.set(
            ret,
            "subvol",
            # Convert from "vol" or {"name" => "vol", "options" => "nocow" } to { "name" => "x", "nocow" => true}
            xml_map.fetch("subvolumes", []).map { |s| import_subvolume(s, sv_prep) }
          )
        end
        if Builtins.haskey(ret, "subvolumes")
          ret = Builtins.remove(ret, "subvolumes")
        end
        Builtins.y2milestone("AddSubvolData ret:%1", ret)
      end
      deep_copy(ret)
    end

    # Build a subvolume representation from a definition
    #
    # This method is suitable to import an AutoYaST profile.
    # It supports two kind of subvolume specification:
    #
    # * just a name
    # * or a hash containing a "name" and an optional "options" keys
    #
    # @param spec_or_name [Hash,String] Subvolume specification
    # @param prefix       [String] Subvolume prefix (usually default subvolume + '/')
    # @return [Hash] Internal representation of a subvolume
    def import_subvolume(spec_or_name, prefix = "")
      log.info "spec_or_name: #{spec_or_name.inspect}"
      # Support strings or hashes
      spec = spec_or_name.is_a?(::String) ? { "name" => spec_or_name } : spec_or_name

      # Base information
      subvolume = {
        "name"   => spec["name"],
        "create" => true
      }
      subvolume["name"].prepend(prefix) unless spec["name"].start_with?(prefix)

      # Append options
      options = spec.fetch("options", "").split(",").map(&:strip).map do |option|
        key, value = option.split("=").map(&:strip)
        [key, value.nil? ? true : value]
      end
      subvolume.merge(Hash[options])
    end

    # Build a subvolume specification from the current definition
    #
    # The result is suitable to be used to generate an AutoYaST profile.
    #
    # @param subvolume [Hash] Subvolume definition (internal storage layer definition)
    # @param prefix    [String] Subvolume prefix (usually default subvolume + '/')
    # @return [Hash] External representation of a subvolume (e.g. to be used by AutoYaST)
    def export_subvolume(subvolume, prefix = "")
      subvolume_spec = {
        "name" => subvolume["name"].sub(/\A#{prefix}/, "")
      }
      subvolume_spec["options"] = "nocow" if subvolume["nocow"]
      subvolume_spec
    end

    def AddFilesysData(st_map, xml_map)
      st_map = deep_copy(st_map)
      xml_map = deep_copy(xml_map)
      ret = AddSubvolData(st_map, xml_map)
      if Ops.get_boolean(ret, "format", false) &&
          !Builtins.isempty(Ops.get_string(xml_map, "mkfs_options", ""))
        Ops.set(
          ret,
          "mkfs_options",
          Ops.get_string(xml_map, "mkfs_options", "")
        )
        Builtins.y2milestone(
          "AddFilesysData mkfs_options:%1",
          Ops.get_string(ret, "mkfs_options", "")
        )
      end
      deep_copy(ret)
    end



    def GetNoneLinuxPartitions(device)
      ret = []
      Builtins.foreach(Storage.GetTargetMap) do |dev, disk|
        if Storage.IsRealDisk(disk) && dev == device
          l = Builtins.filter(Ops.get_list(disk, "partitions", [])) do |p|
            !Ops.get_boolean(p, "delete", false) &&
              !Ops.get_boolean(p, "format", false) &&
              !Partitions.IsLinuxPartition(Ops.get_integer(p, "fsid", 0))
          end

          l = Builtins.filter(l) do |p|
            !Builtins.contains(
              [:xfs, :ext2, :ext3, :ext4, :jfs, :reiser],
              Ops.get_symbol(p, "used_fs", :unknown)
            )
          end
          l = Builtins.filter(l) do |p|
            !FileSystems.IsSystemMp(Ops.get_string(p, "mount", ""), false)
          end
          if Ops.greater_than(Builtins.size(l), 0)
            ln = Builtins.maplist(l) { |p| Ops.get_integer(p, "nr", 0) }
            ret = Builtins.union(ret, ln)
          end
        end
      end
      Builtins.y2milestone("GetNoneLinuxPartitions ret=%1", ret)
      deep_copy(ret)
    end


    def GetAllPartitions(device)
      ret = []
      Builtins.foreach(Storage.GetTargetMap) do |dev, disk|
        if Storage.IsRealDisk(disk) && dev == device
          l = Builtins.maplist(Ops.get_list(disk, "partitions", [])) do |p|
            Ops.get_integer(p, "nr", 0)
          end

          ret = Convert.convert(
            Builtins.union(ret, l),
            :from => "list",
            :to   => "list <integer>"
          )
        end
      end
      Builtins.y2milestone("All Partitions ret=%1", ret)
      deep_copy(ret)
    end

    def propose_default_fs?(partition)
      valid_fsids = [Partitions.fsid_gpt_boot, Partitions.fsid_native]

      (!partition.has_key?("filesystem") ||
       partition["filesystem"] == :none) &&
      valid_fsids.include?(partition["filesystem_id"])
    end

    def raw_partition?(partition)
      valid_fsids = [Partitions.fsid_bios_grub,
                     Partitions.fsid_prep_chrp_boot,
                     Partitions.fsid_gpt_prep]
      valid_fsids.include?(partition["filesystem_id"])
    end
    # Read partition data from XML control file
    # @return [Hash] flexible propsal map
    def preprocess_partition_config(xmlflex)
      xmlflex = deep_copy(xmlflex)
      Builtins.y2debug("xml input: %1", xmlflex)
      tm = Storage.GetTargetMap
      partitioning = Builtins.maplist(xmlflex) do |d|
        dlabel = d.fetch("disklabel", "msdos")
        Builtins.foreach(["keep_partition_id", "keep_partition_num"]) do |key|
          num = []
          nlist2 = Builtins.splitstring(Ops.get_string(d, key, ""), ",")
          Builtins.foreach(nlist2) do |n|
            num = Builtins.union(num, [Builtins.tointeger(n)])
          end
          Ops.set(d, key, num)
        end
        fsys = []
        nlist = Builtins.splitstring(
          Ops.get_string(d, "keep_partition_fsys", ""),
          ","
        )
        Builtins.foreach(nlist) do |n|
          fs = FileSystems.FsToSymbol(n)
          fsys = Builtins.union(fsys, [fs]) if fs != :none
        end
        Ops.set(d, "keep_partition_fsys", fsys)
        user_partitions = Ops.get_list(d, "partitions", [])
        if Builtins.size(user_partitions) == 0
          Builtins.y2milestone(
            "no partitions specified, creating default scheme"
          )
          root = {}
          Ops.set(root, "mount", "/")
          Ops.set(root, "size", "max")
          swap = {}
          Ops.set(swap, "mount", "swap")
          Ops.set(swap, "size", "auto")
          user_partitions = Builtins.add(user_partitions, swap)
          user_partitions = Builtins.add(user_partitions, root)
        end
        partitions = []
        Builtins.foreach(user_partitions) do |partition|
          if Builtins.haskey(partition, "maxsize")
            Ops.set(
              partition,
              "max",
              humanStringToByte(Ops.get_string(partition, "maxsize", ""), true)
            )
          end
          if Ops.get_string(partition, "size", "") != ""
            s = Ops.get_string(partition, "size", "")
            if Builtins.tolower(s) == "auto"
              Ops.set(partition, "size", -1)
            elsif Builtins.tolower(s) == "suspend"
              Ops.set(partition, "size", -2)
            elsif Builtins.tolower(s) == "max"
              Ops.set(partition, "size", 0)
            else
              Ops.set(partition, "size", humanStringToByte(s, true))
            end
          end
          if Ops.less_or_equal(Ops.get_integer(partition, "size", 0), -1) &&
              Ops.get_string(partition, "mount", "") == "swap"
            Ops.set(
              partition,
              "size",
              Ops.multiply(
                1024 * 1024,
                Partitions.SwapSizeMb(
                  0,
                  Ops.get_integer(partition, "size", 0) == -2
                )
              )
            )
          end

          if Ops.get_string(partition, "mount", "") == Partitions.BootMount
            if Ops.get_integer(partition, "size", 0) == -1
              Ops.set(partition, "size", Partitions.MinimalNeededBootsize)
            end

            if Ops.get_integer(partition, "filesystem_id", 0) == 0
              Ops.set(partition, "filesystem_id", Partitions.FsidBoot(dlabel))
            end 

            #partition["max_cyl"] = Partitions::BootCyl();
          end

          #Setting default filesystem if it has not been a part of autoinst.xml
          #Bug 880569
          if propose_default_fs?(partition)
            if partition["mount"] == Partitions.BootMount
              partition["filesystem"] = Partitions.DefaultBootFs
            else
              partition["filesystem"] = Partitions.DefaultFs
            end
          end

          # Do not format raw partitions
          partition["format"] = false if raw_partition?(partition)

          if Ops.get_integer(partition, "size", 0) == -1
            Ops.set(partition, "size", 0)
          end
          if Ops.get_symbol(partition, "used_by_type", :UB_NONE) == :UB_LVM
            Ops.set(partition, "filesystem_id", Partitions.fsid_lvm)
          elsif Ops.get_symbol(partition, "used_by_type", :UB_NONE) == :UB_MD
            Ops.set(partition, "filesystem_id", Partitions.fsid_raid)
          end
          if Builtins.haskey(partition, "filesystem_id")
            Ops.set(
              partition,
              "fsid",
              Ops.get_integer(
                partition,
                "filesystem_id",
                Partitions.fsid_native
              )
            )
          end
          Builtins.y2debug("partition: %1", partition)
          partitions = Builtins.add(partitions, partition)
        end
        if Ops.get_symbol(d, "type", :CT_UNKNONW) != :CT_LVM
          Ops.set(d, "partitions", partitions)
        end
        deep_copy(d)
      end

      Builtins.y2milestone("conf: %1", partitioning)
      deep_copy(partitioning)
    end

    def try_add_boot(conf, disk)
      tc = Builtins.eval(conf)
      # If it is a ppc but not a baremetal Power8 system (powerNV).
      # powerNV do not have prep partition and do not need any because
      # they do not call grub2-install (bnc#989392).
      return tc if Arch.ppc && Arch.board_powernv

      disk = deep_copy(disk)
      dlabel = disk.fetch("label", "")
      root = Ops.greater_than(
        Builtins.size(Builtins.filter(Ops.get_list(conf, "partitions", [])) do |e|
          Ops.get_string(e, "mount", "") == "/"
        end),
        0
      )

      if !@planHasBoot && root &&
         (Ops.greater_than(
           Ops.get_integer(disk, "cyl_count", 0),
           Partitions.BootCyl) || Arch.ppc)
        pb = {}
        # PPCs do not need /boot but prep partition only.
        if !Arch.ppc
          Ops.set(pb, "mount", Partitions.BootMount)
          Ops.set(pb, "fsys", Partitions.DefaultBootFs)
        end
        Ops.set(pb, "size", Partitions.MinimalNeededBootsize)
        Ops.set(pb, "filesystem", Partitions.DefaultBootFs)
        Ops.set(pb, "fsid", Partitions.FsidBoot(dlabel)) # FIXME: might be useless
        Ops.set(pb, "filesystem_id", Partitions.FsidBoot(dlabel))
        Ops.set(pb, "id", Partitions.FsidBoot(dlabel)) # FIXME: might be useless
        Ops.set(pb, "format", false) if raw_partition?(pb)
        Ops.set(pb, "auto_added", true)
        Ops.set(pb, "type", :primary) # FIXME: might be useless
        Ops.set(pb, "partition_type", "primary")
        Ops.set(pb, "nr", 1)
        #pb["max_cyl"] = Partitions::BootCyl();
        #tc["partitions"] = add( tc["partitions"]:[], pb );
        Ops.set(
          tc,
          "partitions",
          Builtins.merge([pb], Ops.get_list(tc, "partitions", []))
        )
        Builtins.y2milestone("boot added automagically pb %1", pb)
      end
      deep_copy(tc)
    end
    def find_matching_disk(disks, target, conf)
      disks = deep_copy(disks)
      target = deep_copy(target)
      conf = deep_copy(conf)
      solutions = {}

      @cur_weight = -100000
      @cur_gap = {}
      Builtins.foreach(disks) do |k|
        e = Ops.get_map(target, k, {})
        pd = deep_copy(conf)
        Builtins.y2milestone("processing disk %1", k)
        Builtins.y2milestone("parts %1", Ops.get_list(conf, "partitions", []))
        tc = try_add_boot(conf, e)
        @cur_mode = :free
        if !Ops.get_boolean(tc, "prefer_remove", false)
          gap = get_gap_info(e, pd, false)
          tc = add_cylinder_info(tc, gap)
          l = get_perfect_list(Ops.get_list(tc, "partitions", []), gap)
          if Ops.greater_than(Builtins.size(l), 0)
            Ops.set(solutions, k, Builtins.eval(l))
            Ops.set(solutions, [k, "disk"], Builtins.eval(e))
          end
          @cur_mode = :reuse
          egap = get_gap_info(e, pd, true)
          if Ops.greater_than(
              Builtins.size(Ops.get_list(egap, "gap", [])),
              Builtins.size(Ops.get_list(gap, "gap", []))
            )
            tc = add_cylinder_info(tc, egap)
            l = get_perfect_list(Ops.get_list(tc, "partitions", []), egap)
            if Ops.greater_than(Builtins.size(l), 0) &&
                (!Builtins.haskey(solutions, k) ||
                  Builtins.haskey(l, "weight") &&
                    Ops.greater_than(
                      Ops.get_integer(l, "weigth", 0),
                      Ops.get_integer(solutions, [k, "weigth"], 0)
                    ))
              Builtins.y2milestone("solution reuse existing")
              Ops.set(solutions, k, Builtins.eval(l))
              Ops.set(solutions, [k, "disk"], Builtins.eval(e))
            end
          end
          @cur_mode = :resize
          rw = try_resize_windows(e)
          if Ops.greater_than(
              Builtins.size(Builtins.filter(Ops.get_list(rw, "partitions", [])) do |p|
                Builtins.haskey(p, "winfo")
              end),
              0
            )
            egap = get_gap_info(rw, pd, true)
            tc = add_cylinder_info(tc, egap)
            l = get_perfect_list(Ops.get_list(tc, "partitions", []), egap)
            if Ops.greater_than(Builtins.size(l), 0) &&
                (!Builtins.haskey(solutions, k) ||
                  Builtins.haskey(l, "weight") &&
                    Ops.greater_than(
                      Ops.get_integer(l, "weigth", 0),
                      Ops.get_integer(solutions, [k, "weigth"], 0)
                    ))
              Builtins.y2milestone("solution resizing windows")
              Ops.set(solutions, k, Builtins.eval(l))
              Ops.set(solutions, [k, "disk"], Builtins.eval(rw))
            end
          end
        else
          @cur_mode = :free
          rp = remove_possible_partitions(e, tc)
          gap = get_gap_info(rp, pd, false)
          tc = add_cylinder_info(tc, gap)
          l = get_perfect_list(Ops.get_list(tc, "partitions", []), gap)
          if Ops.greater_than(Builtins.size(l), 0)
            Ops.set(solutions, k, Builtins.eval(l))
            Ops.set(solutions, [k, "disk"], Builtins.eval(rp))
          end
        end
      end
      ret = {}
      if Ops.greater_than(Builtins.size(solutions), 0)
        Builtins.foreach(solutions) do |k, e|
          Builtins.y2milestone(
            "disk %1 weight %2",
            k,
            Ops.get_integer(e, "weight", 0)
          )
        end
        disks2 = Builtins.maplist(solutions) { |k, e| k }
        disks2 = Builtins.sort(disks2) do |a, b|
          Ops.greater_than(
            Ops.get_integer(solutions, [a, "weight"], 0),
            Ops.get_integer(solutions, [b, "weight"], 0)
          )
        end
        Builtins.y2milestone("sorted disks %1", disks2)
        ret = Ops.get(solutions, Ops.get(disks2, 0, ""), {})
        Ops.set(ret, "device", Ops.get(disks2, 0, ""))
      end
      deep_copy(ret)
    end
    def process_partition_data(dev, solution)
      solution = deep_copy(solution)
      disk = Ops.get_map(solution, "disk", {})
      partitions = []
      value = ""
      mapvalue = {}
      remove_boot = false
      if Ops.greater_than(
          Builtins.size(
            Builtins.filter(Ops.get_list(solution, "partitions", [])) do |e|
              Ops.get_string(e, "mount", "") == Partitions.BootMount &&
                Ops.get_boolean(e, "auto_added", false)
            end
          ),
          0
        )
        Builtins.foreach(Ops.get_list(solution, ["solution", "gap"], [])) do |e|
          Builtins.foreach(Ops.get_list(e, "added", [])) do |a|
            pindex = Ops.get_integer(a, 0, 0)
            if Ops.get_string(solution, ["partitions", pindex, "mount"], "") == "/" &&
                Ops.greater_than(
                  Ops.get_integer(disk, "cyl_count", 0),
                  Partitions.BootCyl
                ) &&
                Ops.less_or_equal(
                  Ops.get_integer(e, "end", 0),
                  Partitions.BootCyl
                )
              remove_boot = true
            end
          end
        end
      end
      index = 0
      if remove_boot
        Builtins.foreach(Ops.get_list(solution, ["solution", "gap"], [])) do |e|
          nlist = []
          Builtins.foreach(Ops.get_list(e, "added", [])) do |a|
            pindex = Ops.get_integer(a, 0, 0)
            if Ops.get_string(solution, ["partitions", pindex, "mount"], "") ==
                Partitions.BootMount
              rest = Ops.get_integer(a, 2, 0)
              Builtins.y2milestone(
                "remove unneeded %3 %1 cyl %2",
                Ops.get_list(e, "added", []),
                rest,
                Partitions.BootMount
              )
              nlist2 = Builtins.filter(Ops.get_list(e, "added", [])) do |l|
                Ops.get_integer(l, 0, 0) != pindex
              end
              if Ops.greater_than(Builtins.size(nlist2), 0) &&
                  !Ops.get_boolean(e, "exists", false)
                weight = Builtins.maplist(nlist2) do |l|
                  Ops.get_integer(l, 2, 0)
                end
                r = {}
                r = distribute_space(
                  rest,
                  weight,
                  nlist2,
                  Ops.get_list(solution, "partitions", [])
                )
                nlist2 = Builtins.eval(Ops.get_list(r, "added", []))
                Ops.set(
                  solution,
                  ["solution", "gap", index, "cylinders"],
                  Ops.subtract(
                    Ops.get_integer(e, "cylinders", 0),
                    Ops.get_integer(r, "diff", 0)
                  )
                )
              end
              Ops.set(
                solution,
                ["solution", "gap", index, "added"],
                Builtins.eval(nlist2)
              )
              Builtins.y2milestone(
                "remove unneeded %2 %1",
                Ops.get_list(e, "added", []),
                Partitions.BootMount
              )
            end
            pindex = Ops.add(pindex, 1)
          end
          index = Ops.add(index, 1)
        end
      end
      index = 0
      Builtins.foreach(Ops.get_list(solution, ["solution", "gap"], [])) do |e|
        if !Ops.get_boolean(e, "exists", false) &&
            Ops.greater_than(Ops.get_integer(e, "cylinders", 0), 0)
          increase = 0
          weight = Builtins.maplist(Ops.get_list(e, "added", [])) do |l|
            Ops.get_boolean(
              solution,
              ["partitions", Ops.get_integer(l, 0, 0), "grow"],
              false
            ) ? 1 : 0
          end
          if Builtins.find(weight) { |l| Ops.greater_than(l, 0) } != nil
            r = {}
            r = distribute_space(
              Ops.get_integer(e, "cylinders", 0),
              weight,
              Ops.get_list(e, "added", []),
              Ops.get_list(solution, "partitions", [])
            )
            Ops.set(
              solution,
              ["solution", "gap", index, "added"],
              Builtins.eval(Ops.get_list(r, "added", []))
            )
            Ops.set(
              solution,
              ["solution", "gap", index, "cylinders"],
              Ops.subtract(
                Ops.get_integer(e, "cylinders", 0),
                Ops.get_integer(r, "diff", 0)
              )
            )
            Builtins.y2milestone(
              "increase increasable p %1 cyl %2",
              Ops.get_list(solution, ["solution", "gap", index, "added"], []),
              Ops.get_integer(
                solution,
                ["solution", "gap", index, "cylinders"],
                0
              )
            )
          end
        end
        index = Ops.add(index, 1)
      end
      Builtins.foreach(Ops.get_list(solution, ["solution", "gap"], [])) do |e|
        if Ops.get_boolean(e, "exists", false)
          index2 = 0
          pindex = Ops.get_integer(e, ["added", 0, 0], 0)
          mount = Ops.get_string(solution, ["partitions", pindex, "mount"], "")
          #                integer fsid = Partitions::fsid_native;
          fsid = Ops.get_integer(
            disk,
            ["partitions", pindex, "fsid"],
            Partitions.fsid_native
          )
          if Ops.get_symbol(disk, ["partitions", pindex, "type"], :primary) != :primary
            fsid = Ops.get_integer(
              disk,
              ["partitions", Ops.add(pindex, 1), "fsid"],
              Partitions.fsid_native
            )
          end
          fsid = Partitions.fsid_swap if mount == "swap"
          if Ops.get_integer(solution, ["partitions", pindex, "fsid"], 0) != 0
            fsid = Ops.get_integer(solution, ["partitions", pindex, "fsid"], 0)
          end
          Builtins.foreach(Ops.get_list(disk, "partitions", [])) do |p|
            if !Ops.get_boolean(p, "delete", false) &&
                Ops.get_integer(p, "nr", 0) ==
                  Ops.get_integer(e, ["added", 0, 1], 0)
              Ops.set(
                p,
                "format",
                Ops.get_boolean(
                  solution,
                  ["partitions", pindex, "format"],
                  true
                )
              )
              if Ops.get_boolean(
                  solution,
                  ["partitions", pindex, "resize"],
                  false
                ) == true
                Ops.set(p, "resize", true)
                Ops.set(
                  p,
                  "region",
                  Ops.get_list(solution, ["partitions", pindex, "region"], [])
                )
              end
              Ops.set(p, "mount", mount)
              if Ops.get_boolean(e, "reuse", false)
                Ops.set(
                  p,
                  "used_fs",
                  Ops.get_symbol(
                    solution,
                    ["partitions", pindex, "filesystem"],
                    Ops.get_symbol(p, "detected_fs") { Partitions.DefaultFs }
                  )
                )
              else
                Ops.set(
                  p,
                  "used_fs",
                  Ops.get_symbol(solution, ["partitions", pindex, "filesystem"]) do
                    Partitions.DefaultFs
                  end
                )
              end
              p = AddFilesysData(
                p,
                Ops.get_map(solution, ["partitions", pindex], {})
              )
              value = Ops.get_string(
                solution,
                ["partitions", pindex, "fstopt"],
                ""
              )
              if Ops.greater_than(Builtins.size(value), 0)
                Ops.set(p, "fstopt", value)
              else
                Ops.set(p, "fstopt", FileSystems.DefaultFstabOptions(p))
              end
              mapvalue = Ops.get_map(
                solution,
                ["partitions", pindex, "fs_options"],
                {}
              )
              if Ops.greater_than(Builtins.size(mapvalue), 0)
                Ops.set(p, "fs_options", mapvalue)
              end
              value = Ops.get_string(
                solution,
                ["partitions", pindex, "label"],
                ""
              )
              mb = Ops.get_symbol(
                solution,
                ["partitions", pindex, "mountby"],
                :no_mb
              )
              Ops.set(p, "mountby", mb) if mb != :no_mb
              if Ops.greater_than(Builtins.size(value), 0)
                Ops.set(p, "label", value)
              end


              if Ops.get_boolean(
                  solution,
                  ["partitions", pindex, "loop_fs"],
                  false
                ) ||
                  Ops.get_boolean(
                    solution,
                    ["partitions", pindex, "crypt_fs"],
                    false
                  )
                #p["loop_fs"]  =	solution["partitions",pindex,"crypt_fs"]:false;
                Ops.set(
                  p,
                  "enc_type",
                  Ops.get_symbol(
                    solution,
                    ["partitions", pindex, "enc_type"],
                    :twofish
                  )
                )
                Storage.SetCryptPwd(
                  Ops.get_string(p, "device", ""),
                  Ops.get_string(
                    solution,
                    ["partitions", pindex, "crypt_key"],
                    ""
                  )
                ) 
                #p["crypt"] =	solution["partitions",pindex,"crypt"]:"twofish256";
              end

              if Ops.get_integer(p, "fsid", 0) != fsid
                Ops.set(p, "change_fsid", true)
                Ops.set(p, "ori_fsid", Ops.get_integer(p, "fsid", 0))
                Ops.set(p, "fsid", fsid)
              end
              if Ops.get_string(
                  solution,
                  ["partitions", pindex, "lvm_group"],
                  ""
                ) != ""
                Ops.set(p, "used_fs", :unknown)
                Ops.set(p, "fsid", Partitions.fsid_lvm)
                Ops.set(p, "format", false)
                Ops.set(
                  p,
                  "lvm_group",
                  Ops.get_string(
                    solution,
                    ["partitions", pindex, "lvm_group"],
                    ""
                  )
                )
                Ops.set(p, "mount", "")
                Ops.set(p, "fstype", "Linux LVM")
              elsif Ops.get_string(
                  solution,
                  ["partitions", pindex, "raid_name"],
                  ""
                ) != ""
                Ops.set(p, "used_fs", :unknown)
                Ops.set(p, "fsid", Partitions.fsid_raid)
                Ops.set(p, "format", false)
                Ops.set(
                  p,
                  "raid_name",
                  Ops.get_string(
                    solution,
                    ["partitions", pindex, "raid_name"],
                    ""
                  )
                )
                Ops.set(
                  p,
                  "raid_type",
                  Ops.get_string(
                    solution,
                    ["partitions", pindex, "raid_type"],
                    "raid"
                  )
                )
                Ops.set(p, "mount", "")
                Ops.set(p, "fstype", "Linux RAID")
              end

              Ops.set(disk, ["partitions", index2], p)
              Builtins.y2milestone("reuse auto partition %1", p)
            end
            index2 = Ops.add(index2, 1)
          end
        else
          region = [
            Ops.get_integer(e, "start", 0),
            Ops.add(
              Ops.subtract(
                Ops.get_integer(e, "end", 0),
                Ops.get_integer(e, "start", 0)
              ),
              1
            )
          ]
          part = {}

          if Ops.get_boolean(e, "extended", false) &&
              Ops.greater_than(Ops.get_integer(e, "created", 0), 0)
            while Ops.less_or_equal(
                Ops.get_integer(
                  e,
                  ["added", 0, 1],
                  Ops.add(Ops.get_integer(disk, "max_primary", 4), 1)
                ),
                Ops.get_integer(disk, "max_primary", 4)
              )
              pindex = Ops.get_integer(e, ["added", 0, 0], 0)
              mount = Ops.get_string(
                solution,
                ["partitions", pindex, "mount"],
                ""
              )
              fsid = Partitions.fsid_native
              fsid = Partitions.fsid_swap if mount == "swap"
              Ops.set(
                part,
                "format",
                Ops.get_boolean(
                  solution,
                  ["partitions", pindex, "format"],
                  true
                )
              )
              if Ops.get_integer(
                  solution,
                  ["partitions", pindex, "filesystem_id"],
                  0
                ) != 0
                fsid = Ops.get_integer(
                  solution,
                  ["partitions", pindex, "filesystem_id"],
                  0
                )
                if !Builtins.haskey(
                    Ops.get_map(solution, ["partitions", pindex], {}),
                    "filesystem"
                  )
                  Ops.set(part, "format", false)
                end
                Builtins.y2milestone(
                  "partition id %1 format %2 part %3",
                  fsid,
                  Ops.get_boolean(part, "format", false),
                  Ops.get_map(solution, ["partitions", pindex], {})
                )
              end
              Ops.set(part, "create", true)
              Ops.set(part, "nr", Ops.get_integer(e, "created", 0))
              Ops.set(
                part,
                "device",
                Storage.GetDeviceName(dev, Ops.get_integer(part, "nr", -1))
              )
              Ops.set(part, "region", region)
              Ops.set(
                part,
                ["region", 1],
                Ops.get_integer(e, ["added", 0, 2], 0)
              )
              Ops.set(
                region,
                0,
                Ops.add(
                  Ops.get_integer(region, 0, 0),
                  Ops.get_integer(part, ["region", 1], 0)
                )
              )
              Ops.set(
                region,
                1,
                Ops.subtract(
                  Ops.get_integer(region, 1, 0),
                  Ops.get_integer(part, ["region", 1], 0)
                )
              )
              Ops.set(part, "type", :primary)
              Ops.set(part, "mount", mount)
              mb = Ops.get_symbol(
                solution,
                ["partitions", pindex, "mountby"],
                :no_mb
              )
              Ops.set(part, "mountby", mb) if mb != :no_mb
              Ops.set(
                part,
                "used_fs",
                Ops.get_symbol(
                  solution,
                  ["partitions", pindex, "filesystem"],
                  mount == "swap" ? :swap : Partitions.DefaultFs
                )
              )
              value = Ops.get_string(
                solution,
                ["partitions", pindex, "fstopt"],
                ""
              )
              if Ops.greater_than(Builtins.size(value), 0)
                Ops.set(part, "fstopt", value)
              else
                Ops.set(part, "fstopt", FileSystems.DefaultFstabOptions(part))
              end
              part = AddFilesysData(
                part,
                Ops.get_map(solution, ["partitions", pindex], {})
              )
              mapvalue = Ops.get_map(
                solution,
                ["partitions", pindex, "fs_options"],
                {}
              )
              if Ops.greater_than(Builtins.size(mapvalue), 0)
                Ops.set(part, "fs_options", mapvalue)
              end

              if Ops.get_boolean(
                  solution,
                  ["partitions", pindex, "loop_fs"],
                  false
                ) ||
                  Ops.get_boolean(
                    solution,
                    ["partitions", pindex, "crypt_fs"],
                    false
                  )
                Ops.set(
                  part,
                  "enc_type",
                  Ops.get_symbol(
                    solution,
                    ["partitions", pindex, "enc_type"],
                    :twofish
                  )
                )
                Storage.SetCryptPwd(
                  Ops.get_string(part, "device", ""),
                  Ops.get_string(
                    solution,
                    ["partitions", pindex, "crypt_key"],
                    ""
                  )
                )
              end

              value = Ops.get_string(
                solution,
                ["partitions", pindex, "label"],
                ""
              )
              if Ops.greater_than(Builtins.size(value), 0)
                Ops.set(part, "label", value)
              end
              Ops.set(part, "fsid", fsid)
              Ops.set(part, "fstype", Partitions.FsIdToString(fsid))
              if Ops.get_string(
                  solution,
                  ["partitions", pindex, "lvm_group"],
                  ""
                ) != ""
                Ops.set(part, "used_fs", :unknown)
                Ops.set(part, "fsid", Partitions.fsid_lvm)
                Ops.set(part, "format", false)
                Ops.set(
                  part,
                  "lvm_group",
                  Ops.get_string(
                    solution,
                    ["partitions", pindex, "lvm_group"],
                    ""
                  )
                )
                Ops.set(part, "mount", "")
                Ops.set(part, "fstype", "Linux LVM")
              elsif Ops.get_string(
                  solution,
                  ["partitions", pindex, "raid_name"],
                  ""
                ) != ""
                Ops.set(part, "used_fs", :unknown)
                Ops.set(part, "fsid", Partitions.fsid_raid)
                Ops.set(part, "format", false)
                Ops.set(
                  part,
                  "raid_name",
                  Ops.get_string(
                    solution,
                    ["partitions", pindex, "raid_name"],
                    ""
                  )
                )
                Ops.set(
                  part,
                  "raid_type",
                  Ops.get_string(
                    solution,
                    ["partitions", pindex, "raid_type"],
                    "raid"
                  )
                )
                Ops.set(part, "mount", "")
                Ops.set(part, "fstype", "Linux RAID")
              end
              Builtins.y2milestone(
                "process_partition_data auto partition %1",
                part
              )
              partitions = Builtins.add(partitions, part)
              Ops.set(e, "created", Ops.get_integer(e, ["added", 0, 1], 0))
              Ops.set(
                e,
                "added",
                Builtins.remove(Ops.get_list(e, "added", []), 0)
              )
              part = {}
            end
            Ops.set(part, "create", true)
            Ops.set(part, "nr", Ops.get_integer(e, "created", 0))
            Ops.set(
              part,
              "device",
              Storage.GetDeviceName(dev, Ops.get_integer(part, "nr", -1))
            )
            Ops.set(part, "region", Builtins.eval(region))
            Ops.set(part, "type", :extended)
            Ops.set(part, "fsid", Partitions.fsid_extended_win)
            Ops.set(
              part,
              "fstype",
              Partitions.FsIdToString(Ops.get_integer(part, "fsid", 0))
            )
            Ops.set(
              part,
              "size_k",
              Ops.divide(
                Ops.multiply(
                  Ops.get_integer(region, 1, 0),
                  Ops.get_integer(disk, "cyl_size", 0)
                ),
                1024
              )
            )
            Builtins.y2milestone("extended auto partition %1", part)
            partitions = Builtins.add(partitions, Builtins.eval(part))
          end
          Builtins.foreach(Ops.get_list(e, "added", [])) do |a|
            part = {}
            pindex = Ops.get_integer(a, 0, 0)
            mount = Ops.get_string(
              solution,
              ["partitions", pindex, "mount"],
              ""
            )
            fsid = Partitions.fsid_native
            Ops.set(
              part,
              "format",
              Ops.get_boolean(solution, ["partitions", pindex, "format"], true)
            )
            fsid = Partitions.fsid_swap if mount == "swap"
            if Ops.get_integer(
                solution,
                ["partitions", pindex, "filesystem_id"],
                0
              ) != 0
              fsid = Ops.get_integer(
                solution,
                ["partitions", pindex, "filesystem_id"],
                0
              )
              if !Builtins.haskey(
                  Ops.get_map(solution, ["partitions", pindex], {}),
                  "filesystem"
                )
                Ops.set(part, "format", false)
              end
              Builtins.y2milestone(
                "partition id %1 format %2 part %3",
                fsid,
                Ops.get_boolean(part, "format", false),
                Ops.get_map(solution, ["partitions", pindex], {})
              )
            end
            Ops.set(part, "create", true)
            Ops.set(part, "nr", Ops.get_integer(a, 1, 0))
            Ops.set(
              part,
              "device",
              Storage.GetDeviceName(dev, Ops.get_integer(part, "nr", 0))
            )
            Ops.set(region, 1, Ops.get_integer(a, 2, 0))
            Ops.set(part, "region", Builtins.eval(region))
            Ops.set(
              region,
              0,
              Ops.add(
                Ops.get_integer(region, 0, 0),
                Ops.get_integer(region, 1, 0)
              )
            )
            Ops.set(part, "type", :primary)
            if Ops.get_boolean(e, "extended", false)
              Ops.set(part, "type", :logical)
            end
            Ops.set(part, "mount", mount)
            mb = Ops.get_symbol(
              solution,
              ["partitions", pindex, "mountby"],
              :no_mb
            )
            Ops.set(part, "mountby", mb) if mb != :no_mb
            Ops.set(
              part,
              "used_fs",
              Ops.get_symbol(
                solution,
                ["partitions", pindex, "filesystem"],
                mount == "swap" ? :swap : Partitions.DefaultFs
              )
            )
            value = Ops.get_string(
              solution,
              ["partitions", pindex, "fstopt"],
              ""
            )
            if Ops.greater_than(Builtins.size(value), 0)
              Ops.set(part, "fstopt", value)
            else
              Ops.set(part, "fstopt", FileSystems.DefaultFstabOptions(part))
            end
            part = AddFilesysData(
              part,
              Ops.get_map(solution, ["partitions", pindex], {})
            )
            mapvalue = Ops.get_map(
              solution,
              ["partitions", pindex, "fs_options"],
              {}
            )
            if Ops.greater_than(Builtins.size(mapvalue), 0)
              Ops.set(part, "fs_options", mapvalue)
            end
            if Ops.get_boolean(
                solution,
                ["partitions", pindex, "loop_fs"],
                false
              ) ||
                Ops.get_boolean(
                  solution,
                  ["partitions", pindex, "crypt_fs"],
                  false
                )
              #part["loop_fs"]  =	solution["partitions",pindex,"crypt_fs"]:false;
              Ops.set(
                part,
                "enc_type",
                Ops.get_symbol(
                  solution,
                  ["partitions", pindex, "enc_type"],
                  :twofish
                )
              )
              Storage.SetCryptPwd(
                Ops.get_string(part, "device", ""),
                Ops.get_string(
                  solution,
                  ["partitions", pindex, "crypt_key"],
                  ""
                )
              ) 
              #part["crypt"] =	solution["partitions",pindex,"crypt"]:"twofish256";
            end
            value = Ops.get_string(
              solution,
              ["partitions", pindex, "label"],
              ""
            )
            if Ops.greater_than(Builtins.size(value), 0)
              Ops.set(part, "label", value)
            end
            Ops.set(part, "fsid", fsid)
            Ops.set(part, "fstype", Partitions.FsIdToString(fsid))
            if Ops.get_string(solution, ["partitions", pindex, "lvm_group"], "") != ""
              Ops.set(part, "used_fs", :unknown)
              Ops.set(part, "fsid", Partitions.fsid_lvm)
              Ops.set(part, "format", false)
              Ops.set(
                part,
                "lvm_group",
                Ops.get_string(
                  solution,
                  ["partitions", pindex, "lvm_group"],
                  ""
                )
              )
              Ops.set(part, "mount", "")
              Ops.set(part, "fstype", "Linux LVM")
            elsif Ops.get_string(
                solution,
                ["partitions", pindex, "raid_name"],
                ""
              ) != ""
              Ops.set(part, "used_fs", :unknown)
              Ops.set(part, "fsid", Partitions.fsid_raid)
              Ops.set(part, "format", false)
              Ops.set(
                part,
                "raid_name",
                Ops.get_string(
                  solution,
                  ["partitions", pindex, "raid_name"],
                  ""
                )
              )
              Ops.set(
                part,
                "raid_type",
                Ops.get_string(
                  solution,
                  ["partitions", pindex, "raid_type"],
                  "raid"
                )
              )
              Ops.set(part, "mount", "")
              Ops.set(part, "fstype", "Linux RAID")
            end
            Builtins.y2milestone("auto partition %1", part)
            partitions = Builtins.add(partitions, Builtins.eval(part))
            if Ops.add(Ops.get_integer(a, 1, 0), 1) ==
                Ops.get_integer(e, "created", 0) &&
                Ops.get_boolean(e, "extended", false)
              part = {}
              ext_region = [
                Ops.get_integer(region, 0, 0),
                Ops.add(
                  Ops.subtract(
                    Ops.get_integer(e, "end", 0),
                    Ops.get_integer(region, 0, 0)
                  ),
                  1
                )
              ]
              Ops.set(part, "create", true)
              Ops.set(part, "nr", Ops.get_integer(e, "created", 0))
              Ops.set(
                part,
                "device",
                Storage.GetDeviceName(dev, Ops.get_integer(part, "nr", -1))
              )
              Ops.set(part, "region", ext_region)
              Ops.set(part, "type", :extended)
              Ops.set(part, "fsid", Partitions.fsid_extended_win)
              Ops.set(
                part,
                "fstype",
                Partitions.FsIdToString(Ops.get_integer(part, "fsid", 0))
              )
              Builtins.y2milestone("extended auto partition %1", part)
              partitions = Builtins.add(partitions, Builtins.eval(part))
            end
          end
          partitions = Builtins.sort(partitions) do |a, b|
            Ops.less_than(
              Ops.get_integer(a, "nr", 0),
              Ops.get_integer(b, "nr", 0)
            )
          end
        end
      end
      Ops.set(
        disk,
        "partitions",
        Builtins.union(Ops.get_list(disk, "partitions", []), partitions)
      )
      Builtins.y2milestone("disk %1", disk)
      deep_copy(disk)
    end

    def find_matching_partition_size(gap, nr)
      gap = deep_copy(gap)
      mg = Builtins.filter(Ops.get_list(gap, "gap", [])) do |g|
        Ops.get_integer(g, "nr", -1) == nr && Ops.get_boolean(g, "reuse", false)
      end
      Builtins.y2milestone("usepart partition: %1", Ops.get_map(mg, 0, {}))
      Ops.get_map(mg, 0, {})
    end
    def add_cylinder_info(conf, gap)
      conf = deep_copy(conf)
      gap = deep_copy(gap)
      big_cyl = 4 * 1024 * 1024 * 1024
      cyl_size = Ops.get_integer(gap, "cyl_size", 1)
      #   // FIXME: Why is sorting needed here?
      # conf["partitions"] =
      #     sort( map a, map b, conf["partitions"]:[],
      #           ``({
      #               if( a["max_cyl"]:big_cyl != b["max_cyl"]:big_cyl )
      #                   return( a["max_cyl"]:big_cyl < b["max_cyl"]:big_cyl );
      #               else
      #                   return( a["size"]:0 > b["size"]:0 );
      #           }));
      Builtins.y2milestone("parts %1", Ops.get_list(conf, "partitions", []))
      sum = 0
      Ops.set(
        conf,
        "partitions",
        Builtins.maplist(Ops.get_list(conf, "partitions", [])) do |p|
          sum = Ops.add(sum, Ops.get_integer(p, "pct", 0))
          Ops.set(
            p,
            "cylinders",
            Ops.divide(
              Ops.subtract(Ops.add(Ops.get_integer(p, "size", 0), cyl_size), 1),
              cyl_size
            )
          )
          # p["cylinders"] = (p["size"]:0)/cyl_size;
          mg = find_matching_partition_size(
            gap,
            Ops.get_integer(p, "usepart", 0)
          )
          if mg != {}
            # need next two lines because of #284102
            # FIXME: check problems with resizing
            Ops.set(p, "cylinders", Ops.get_integer(mg, "cylinders", 0))
            Ops.set(p, "size", Ops.get_integer(mg, "size", 0))
            if Ops.less_than(
                Ops.get_integer(p, "usepart", 0),
                Ops.get_integer(gap, "max_primary", 0)
              )
              Ops.set(p, "partition_type", "primary")
            end
          end
          Ops.set(p, "cylinders", 1) if Ops.get_integer(p, "cylinders", 0) == 0
          deep_copy(p)
        end
      )
      Builtins.y2milestone("sum %1", sum)
      Builtins.y2milestone("parts %1", Ops.get_list(conf, "partitions", []))
      if Ops.greater_than(sum, 100)
        rest = Ops.subtract(sum, 100)
        Ops.set(
          conf,
          "partitions",
          Builtins.maplist(Ops.get_list(conf, "partitions", [])) do |p|
            if Builtins.haskey(p, "pct")
              pct = Ops.get_integer(p, "pct", 0)
              diff = Ops.divide(
                Ops.add(Ops.multiply(rest, pct), Ops.divide(sum, 2)),
                sum
              )
              sum = Ops.subtract(sum, pct)
              rest = Ops.subtract(rest, diff)
              Ops.set(p, "pct", Ops.subtract(pct, diff))
            end
            deep_copy(p)
          end
        )
      end
      Ops.set(
        conf,
        "partitions",
        Builtins.maplist(Ops.get_list(conf, "partitions", [])) do |p|
          if Builtins.haskey(p, "pct")
            cyl = Ops.multiply(
              Ops.divide(Ops.get_integer(gap, "sum", 0), 100),
              Ops.get_integer(p, "pct", 0)
            )
            cyl = Ops.divide(Ops.add(cyl, Ops.divide(cyl_size, 2)), cyl_size)
            cyl = 1 if cyl == 0
            Ops.set(p, "want_cyl", cyl)
          end
          if Ops.greater_than(Ops.get_integer(p, "max", 0), 0)
            cyl = Ops.divide(
              Ops.subtract(Ops.add(Ops.get_integer(p, "max", 0), cyl_size), 1),
              cyl_size
            )
            Ops.set(p, "size_max_cyl", cyl)
            if Ops.greater_than(Ops.get_integer(p, "want_cyl", 0), cyl)
              Ops.set(p, "want_cyl", cyl)
            end
          end
          deep_copy(p)
        end
      )
      Builtins.y2milestone("parts %1", Ops.get_list(conf, "partitions", []))
      deep_copy(conf)
    end
    def get_perfect_list(ps, g)
      ps = ps.reject { |p| p.fetch("partition_nr",1)==0 }
      g = deep_copy(g)
      Builtins.y2milestone("requested partitions  %1", ps)
      Builtins.y2milestone("calculated gaps %1", g)

      ps = Builtins.maplist(
        Convert.convert(ps, :from => "list", :to => "list <map>")
      ) do |partition|
        if Ops.get_boolean(partition, "resize", false)
          # this is a cylinder correction for resized partitions
          # bnc#580842
          Ops.set(
            partition,
            "cylinders",
            Ops.get_integer(partition, ["region", 1], 0)
          )
          Builtins.y2milestone(
            "cylinder correction to %1",
            Ops.get_integer(partition, "cylinders", 0)
          )
        end
        deep_copy(partition)
      end

      Builtins.foreach(
        Convert.convert(ps, :from => "list", :to => "list <map>")
      ) do |rp|
        if Ops.get_boolean(rp, "resize", false)
          new_cyl_size = 0
          cyl_size_change = 0
          old_end = 0
          new_end = 0
          Ops.set(g, "gap", Builtins.maplist(Ops.get_list(g, "gap", [])) do |gap|
            Builtins.y2milestone("working on gap %1", gap)
            if new_cyl_size != 0
              Ops.set(
                gap,
                "cylinders",
                Ops.add(Ops.get_integer(gap, "cylinders", 0), cyl_size_change)
              )
              Ops.set(
                gap,
                "start",
                Ops.subtract(Ops.get_integer(gap, "start", 0), cyl_size_change)
              )
              Ops.set(
                gap,
                "size",
                Ops.add(
                  Ops.get_integer(gap, "size", 0),
                  Ops.multiply(
                    cyl_size_change,
                    Ops.get_integer(g, "cyl_size", 0)
                  )
                )
              )
              Builtins.y2milestone(
                "changing gap because of a resize of a previous partition gap is now: cyl=%1 start=%2 size=%3",
                Ops.get_integer(gap, "cylinders", 0),
                Ops.get_integer(gap, "start", 0),
                Ops.get_integer(gap, "size", 0)
              )
              new_cyl_size = 0
            elsif Ops.get_integer(gap, "nr", -1) ==
                Ops.get_integer(rp, "partition_nr", -2)
              new_cyl_size = Ops.get_integer(rp, "cylinders", 0)
              cyl_size_change = Ops.subtract(
                Ops.get_integer(gap, "cylinders", 0),
                new_cyl_size
              )
              old_end = Ops.get_integer(gap, "end", 0)
              Builtins.y2milestone(
                "partition resize cyl_size_change=%1",
                cyl_size_change
              )

              Ops.set(gap, "cylinders", new_cyl_size)
              #gap["size"] = gap["size"]:0 + cyl_size_change * g["cyl_size"]:0;
              Ops.set(
                gap,
                "size",
                Ops.multiply(new_cyl_size, Ops.get_integer(g, "cyl_size", 0))
              )
              Ops.set(
                gap,
                "end",
                Ops.subtract(
                  Ops.add(Ops.get_integer(gap, "start", 0), new_cyl_size),
                  1
                )
              )
              new_end = Ops.get_integer(gap, "end", 0)
              Builtins.y2milestone("changing gap to %1", gap)
            end
            deep_copy(gap)
          end)
          if new_cyl_size != 0
            new_gap = {}
            Ops.set(new_gap, "cylinders", cyl_size_change)
            Ops.set(
              new_gap,
              "size",
              Ops.multiply(cyl_size_change, Ops.get_integer(g, "cyl_size", 0))
            )
            Ops.set(new_gap, "start", Ops.add(new_end, 1))
            Ops.set(new_gap, "end", old_end)
            Ops.set(
              new_gap,
              "size",
              Ops.add(
                Ops.subtract(
                  Ops.get_integer(new_gap, "end", 0),
                  Ops.get_integer(new_gap, "start", 0)
                ),
                1
              )
            )
            Ops.set(g, "gap", Builtins.add(Ops.get_list(g, "gap", []), new_gap))
            Builtins.y2milestone("added new gap after shrinking %1", new_gap)
          end
        end
      end

      # If gaps are available
      # AND (
      # extended partitions are possible and there are
      # primaries left and number of requested partitions(+1) is less than all available
      # primaries and logical slots
      # OR
      # extended is not possible and number of requested partitions is less than all
      # available primaries and logical slots )

      new_ps = ps.count { |p| p.fetch("create", true) }
      reuse_ps = ps.count { |p| p.fetch("partition_nr",0)==p.fetch("usepart",-1) }
      free_pnr = g.fetch("free_pnr",[]).size
      if g.fetch("extended_possible",false)
        free_pnr -= 1
        free_pnr += g.fetch("ext_pnr",[]).size
      end
      Builtins.y2milestone(
        "get_perfect_list: size(ps):%1 new_ps:%2 reuse_ps:%3 sum_free:%4",
        ps.size, new_ps, reuse_ps, free_pnr
      )
      if (new_ps>0||reuse_ps>0) && g.fetch("gap", []).size>0 && new_ps<=free_pnr 
        lg = Builtins.eval(g)

        # prepare local gap var
        Ops.set(lg, "gap", Builtins.maplist(Ops.get_list(lg, "gap", [])) do |e|
          Ops.set(e, "orig_cyl", Ops.get_integer(e, "cylinders", 0))
          Ops.set(e, "added", [])
          deep_copy(e)
        end)
        Ops.set(lg, "procpart", 0)

        lp = Builtins.eval(ps)

        add_prim = Builtins.size(
          Builtins.filter(
            Convert.convert(ps, :from => "list", :to => "list <map>")
          ) do |up|
            (Ops.get_string(up, "partition_type", "none") == "primary" ||
              Builtins.contains(
                Ops.get_list(lg, "free_pnr", []),
                Ops.get_integer(up, "partition_nr", 0)
              )) &&
              Ops.get_boolean(up, "create", true)
          end
        )
        Builtins.y2milestone(
          "get_perfect_list new_ps:%1 add_prim:%2 free_prim:%3",
          new_ps,
          add_prim,
          Builtins.size(Ops.get_list(g, "free_pnr", []))
        )
        if g.fetch("extended_possible",false) &&
           g.fetch("free_pnr",[]).size>0 &&
	   add_prim<g.fetch("free_pnr",[]).size &&
	   new_ps>add_prim
          Builtins.y2milestone("creating extended")
          index = 0
          Builtins.foreach(Ops.get_list(lg, "gap", [])) do |e|
            if !Ops.get_boolean(e, "exists", false)
              gap = Builtins.eval(lg)
              Ops.set(
                gap,
                ["gap", index, "created"],
                Ops.get_integer(gap, ["free_pnr", 0], 1)
              )
              Ops.set(
                gap,
                "free_pnr",
                Builtins.remove(
                  Convert.convert(
                    Ops.get(gap, "free_pnr") { [1] },
                    :from => "any",
                    :to   => "list <const integer>"
                  ),
                  0
                )
              )
              Ops.set(gap, ["gap", index, "extended"], true)
              Ops.set(gap, "extended_possible", false)
              add_part_recursive(ps, gap)
            end
            index = Ops.add(index, 1)
          end
        end
        if Ops.less_or_equal(
            new_ps,
            Ops.add(
              Builtins.size(Ops.get_list(g, "free_pnr", [])),
              Builtins.size(Ops.get_list(g, "ext_pnr", []))
            )
          )
          Builtins.y2milestone("not creating extended now")
          add_part_recursive(ps, lg)
        end
      end
      ret = {}
      if @cur_gap.size>0
	ret["weight"] = @cur_weight
        ret["solution"] = @cur_gap
        ret["partitions"] = ps
      elsif ps.size==0 
	ret["weight"] = 0
        ret["solution"] = []
        ret["partitions"] = []
      end
      Builtins.y2milestone(
        "ret weight %1",
        Ops.get_integer(ret, "weight", -1000000)
      )
      Builtins.y2milestone(
        "ret solution %1",
        Ops.get_list(ret, ["solution", "gap"], [])
      )
      deep_copy(ret)
    end
    def add_part_recursive(ps, g)
      ps = deep_copy(ps)
      g = deep_copy(g)
      Builtins.y2milestone(
        "add_part_recursive partition index %1",
        Ops.get_integer(g, "procpart", 0)
      )
      Builtins.y2milestone("add_part_recursive partitions %1", ps)
      Builtins.y2milestone("add_part_recursive gap %1", g)

      # creation_needed indicates the case, that we do not
      # create a single partition but are reusing some
      creation_needed = false
      Builtins.foreach(
        Convert.convert(ps, :from => "list", :to => "list <map>")
      ) do |p|
        creation_needed = true if Ops.get_boolean(p, "create", true) == true
      end
      Builtins.y2milestone(
        "add_part_recursive creation is needed? %1",
        creation_needed
      )


      lg = Builtins.eval(g)
      gindex = 0
      pindex = Ops.get_integer(lg, "procpart", 0)
      part = Ops.get_map(ps, pindex, {})
      Ops.set(lg, "procpart", Ops.add(pindex, 1))
      Builtins.y2milestone("working on partition %1", part)
      Builtins.foreach(Ops.get_list(lg, "gap", [])) do |e|
        Builtins.y2milestone("add_part_recursive start: gap section  %1", e)
        # speed up partitioning calculation (bnc#620212)
        reuseCondition = true
        if Ops.get_boolean(part, "create", true) == false &&
            Builtins.haskey(part, "partition_nr") &&
              Ops.get_integer(part, "partition_nr", 0) !=
                Ops.get_integer(e, "nr", 0)
          Builtins.y2milestone(
            "gap can't be used. %1 != %2",
            Ops.get_integer(part, "partition_nr", 0),
            Ops.get_integer(e, "nr", 0)
          )
          reuseCondition = false
        end
        primary = Ops.get_string(part, "partition_type", "none") == "primary"
        if reuseCondition &&
            Ops.less_or_equal(
              Ops.get_integer(part, "max_cyl", 0),
              Ops.get_integer(e, "end", 0)
            ) &&
            Ops.less_or_equal(
              Ops.get_integer(part, "cylinders", 0),
              Ops.get_integer(e, "cylinders", 0)
            ) &&
            (!creation_needed ||
              !Ops.get_boolean(e, "extended", false) &&
                Ops.greater_than(
                  Builtins.size(Ops.get_list(lg, "free_pnr", [])),
                  0
                ) ||
              primary && Ops.greater_than(Ops.get_integer(e, "created", 0), 0) &&
                Ops.get_boolean(e, "extended", false) &&
                Ops.greater_than(
                  Builtins.size(Ops.get_list(lg, "free_pnr", [])),
                  0
                ) ||
              !primary && Ops.get_boolean(e, "extended", false) &&
                Ops.greater_than(
                  Builtins.size(Ops.get_list(lg, "ext_pnr", [])),
                  0
                ))
          llg = Builtins.eval(lg)
          if Ops.get_boolean(e, "exists", false)
            Ops.set(llg, ["gap", gindex, "cylinders"], 0)
          else
            Ops.set(
              llg,
              ["gap", gindex, "cylinders"],
              Ops.subtract(
                Ops.get_integer(llg, ["gap", gindex, "cylinders"], 0),
                Ops.get_integer(part, "cylinders", 0)
              )
            )
          end
          addl = [pindex]
          if Ops.get_boolean(e, "exists", false) ||
              Ops.get_boolean(e, "reuse", false)
            addl = Builtins.add(addl, Ops.get_integer(e, "nr", 0))
          elsif Ops.get_boolean(e, "extended", false) && !primary
            addl = Builtins.add(addl, Ops.get_integer(llg, ["ext_pnr", 0], 5))
            Ops.set(
              llg,
              "ext_pnr",
              Builtins.remove(
                Convert.convert(
                  Ops.get(llg, "ext_pnr") { [0] },
                  :from => "any",
                  :to   => "list <const integer>"
                ),
                0
              )
            )
          else
            addl = Builtins.add(addl, Ops.get_integer(llg, ["free_pnr", 0], 1))
            Ops.set(
              llg,
              "free_pnr",
              Builtins.remove(
                Convert.convert(
                  Ops.get(llg, "free_pnr") { [0] },
                  :from => "any",
                  :to   => "list <const integer>"
                ),
                0
              )
            )
          end
          Ops.set(
            llg,
            ["gap", gindex, "added"],
            Builtins.add(Ops.get_list(llg, ["gap", gindex, "added"], []), addl)
          )

          if Ops.less_than(Ops.add(pindex, 1), Builtins.size(ps))
            add_part_recursive(ps, llg)
          else
            ng = normalize_gaps(ps, llg)
            val = do_weighting(ps, ng)
            Builtins.y2milestone(
              "add_part_recursive val %1 cur_weight %2 size %3",
              val,
              @cur_weight,
              Builtins.size(@cur_gap)
            )
            if Ops.greater_than(val, @cur_weight) ||
                Builtins.size(@cur_gap) == 0
              @cur_weight = val
              @cur_gap = Builtins.eval(ng)
            end
          end
        end
        gindex = Ops.add(gindex, 1)
      end

      nil
    end
    def normalize_gaps(ps, g)
      ps = deep_copy(ps)
      g = deep_copy(g)
      Builtins.y2milestone("normalize_gaps: gap %1", g)
      gindex = 0
      pindex = 0
      Builtins.foreach(Ops.get_list(g, "gap", [])) do |e|
        Builtins.y2milestone("gap section %1", e)
        if Ops.get_boolean(e, "exists", false)
          if Ops.greater_than(Builtins.size(Ops.get_list(e, "added", [])), 0) &&
              Builtins.size(Ops.get_list(e, ["added", 0], [])) == 2
            Ops.set(
              e,
              ["added", 0],
              Builtins.add(
                Ops.get_list(e, ["added", 0], []),
                Ops.get_integer(e, "orig_cyl", 1)
              )
            )
          end
        else
          rest = Ops.get_integer(e, "cylinders", 0)
          needed = 0
          tidx = 0
          Builtins.foreach(Ops.get_list(e, "added", [])) do |p|
            tidx = Ops.get_integer(p, 0, 0)
            if Ops.greater_than(
                Ops.get_integer(ps, [tidx, "want_cyl"], 0),
                Ops.get_integer(ps, [tidx, "cylinders"], 0)
              )
              needed = Ops.subtract(
                Ops.add(needed, Ops.get_integer(ps, [tidx, "want_cyl"], 0)),
                Ops.get_integer(ps, [tidx, "cylinders"], 0)
              )
            end
          end
          Builtins.y2milestone("needed %1 rest %2", needed, rest)
          if Ops.greater_than(needed, rest)
            tr = []
            weight = Builtins.maplist(Ops.get_list(e, "added", [])) do |l|
              idx = Ops.get_integer(l, 0, 0)
              d = Ops.subtract(
                Ops.get_integer(ps, [idx, "want_cyl"], 0),
                Ops.get_integer(ps, [idx, "cylinders"], 0)
              )
              if Ops.greater_than(d, 0)
                l = Builtins.add(l, Ops.get_integer(ps, [idx, "cylinders"], 0))
              end
              tr = Builtins.add(tr, l)
              Ops.greater_than(d, 0) ? d : 0
            end
            Builtins.y2milestone("tr %1", tr)
            r = {}
            r = distribute_space(rest, weight, tr, ps)
            Ops.set(
              g,
              ["gap", gindex, "added"],
              Builtins.eval(Ops.get_list(r, "added", []))
            )
            Ops.set(
              g,
              ["gap", gindex, "cylinders"],
              Ops.subtract(
                Ops.get_integer(e, "cylinders", 0),
                Ops.get_integer(r, "diff", 0)
              )
            )
            Builtins.y2milestone(
              "partly satisfy %1 cyl %2",
              Ops.get_list(g, ["gap", gindex, "added"], []),
              Ops.get_integer(g, ["gap", gindex, "cylinders"], 0)
            )
          else
            Ops.set(
              g,
              ["gap", gindex, "cylinders"],
              Ops.subtract(Ops.get_integer(e, "cylinders", 0), needed)
            )
          end

          pindex = 0
          Builtins.foreach(Ops.get_list(g, ["gap", gindex, "added"], [])) do |p|
            if Ops.less_than(Builtins.size(p), 3)
              tidx = Ops.get_integer(p, 0, 0)
              if Ops.greater_than(
                  Ops.get_integer(ps, [tidx, "want_cyl"], 0),
                  Ops.get_integer(ps, [tidx, "cylinders"], 0)
                )
                p = Builtins.add(p, Ops.get_integer(ps, [tidx, "want_cyl"], 0))
              else
                p = Builtins.add(p, Ops.get_integer(ps, [tidx, "cylinders"], 0))
              end
              Ops.set(g, ["gap", gindex, "added", pindex], p)
              Builtins.y2milestone(
                "satisfy p %1 cyl %2",
                p,
                Ops.get_integer(e, "cylinders", 0)
              )
            end
            pindex = Ops.add(pindex, 1)
          end
          Builtins.y2milestone(
            "added %1",
            Ops.get_list(g, ["gap", gindex, "added"], [])
          )
        end
        gindex = Ops.add(gindex, 1)
      end
      gindex = 0
      Builtins.foreach(Ops.get_list(g, "gap", [])) do |e|
        if !Ops.get_boolean(e, "exists", false) &&
            Ops.greater_than(Ops.get_integer(e, "cylinders", 0), 0)
          weight = Builtins.maplist(Ops.get_list(e, "added", [])) do |l|
            Ops.get_integer(ps, [Ops.get_integer(l, 0, 0), "size"], 0) == 0 ? 1 : 0
          end
          if Builtins.find(weight) { |l| Ops.greater_than(l, 0) } != nil
            r = {}
            r = distribute_space(
              Ops.get_integer(e, "cylinders", 0),
              weight,
              Ops.get_list(e, "added", []),
              ps
            )
            Ops.set(
              g,
              ["gap", gindex, "added"],
              Builtins.eval(Ops.get_list(r, "added", []))
            )
            Ops.set(
              g,
              ["gap", gindex, "cylinders"],
              Ops.subtract(
                Ops.get_integer(e, "cylinders", 0),
                Ops.get_integer(r, "diff", 0)
              )
            )
            Builtins.y2milestone(
              "increase max p %1 cyl %2",
              Ops.get_list(g, ["gap", gindex, "added"], []),
              Ops.get_integer(g, ["gap", gindex, "cylinders"], 0)
            )
          end
        end
        gindex = Ops.add(gindex, 1)
      end
      gindex = 0
      # makes trouble on small harddisks
      # foreach( map e, g["gap"]:[],
      #          ``{
      #     if( !e["exists"]:false && e["cylinders"]:0>0 &&
      #         e["cylinders"]:0 < g["disk_cyl"]:0/20 )
      #     {
      #         list weight = maplist( list l, e["added"]:[], ``(l[2]:0) );
      #         map r = $[];
      #         r = distribute_space( e["cylinders"]:0, weight, e["added"]:[], ps );
      #         g["gap",gindex,"added"] = eval(r["added"]:[]);
      #         g["gap",gindex,"cylinders"] = e["cylinders"]:0 - r["diff"]:0;
      #         y2milestone( "close small gap p %1 cyl %2", g["gap",gindex,"added"]:[],
      #                      g["gap",gindex,"cylinders"]:0 );
      #     }
      #     gindex = gindex + 1;
      # });
      Builtins.foreach(g.fetch("gap",[])) do |e|
        if !e.fetch("exists",false) && e.fetch("added",[]).size>1
          Builtins.y2milestone( "normalize_gaps old added %1", e.fetch("added",[]))
          sdd = Builtins.sort(e.fetch("added",[])) do |a, b|
	    a.fetch(1,0)<=b.fetch(1,0)
          end
          Ops.set(g, ["gap", gindex, "added"], sdd)
          Builtins.y2milestone(
            "normalize_gaps sort added %1",
            Ops.get_list(g, ["gap", gindex, "added"], [])
          )
        end
        gindex += 1
      end
      Builtins.y2milestone("normalize_gaps ret %1", g)
      deep_copy(g)
    end
    def distribute_space(rest, weights, added, ps)
      weights = deep_copy(weights)
      added = deep_copy(added)
      ps = deep_copy(ps)
      diff_sum = 0
      sum = 0
      index = 0
      pindex = 0
      Builtins.y2milestone("rest %1 weights %2 added %3", rest, weights, added)
      Builtins.foreach(
        Convert.convert(added, :from => "list", :to => "list <list>")
      ) do |p|
        pindex = Ops.get_integer(p, 0, 0)
        if Ops.get_integer(ps, [pindex, "size_max_cyl"], 0) == 0 ||
            Ops.get_boolean(ps, [pindex, "grow"], false) ||
            Ops.greater_than(
              Ops.get_integer(ps, [pindex, "size_max_cyl"], 0),
              Ops.get_integer(p, 2, 0)
            )
          sum = Ops.add(sum, Ops.get_integer(weights, index, 0))
        end
        index = Ops.add(index, 1)
      end
      index = 0
      Builtins.y2milestone("sum %1 rest %2 added %3", sum, rest, added)
      Builtins.foreach(
        Convert.convert(added, :from => "list", :to => "list <list>")
      ) do |p|
        pindex = Ops.get_integer(p, 0, 0)
        if Builtins.size(p) == 3 && Ops.greater_than(sum, 0) &&
            (Ops.get_integer(ps, [pindex, "size_max_cyl"], 0) == 0 ||
              Ops.get_boolean(ps, [pindex, "grow"], false) ||
              Ops.greater_than(
                Ops.get_integer(ps, [pindex, "size_max_cyl"], 0),
                Ops.get_integer(p, 2, 0)
              ))
          diff = Ops.divide(
            Ops.add(
              Ops.multiply(rest, Ops.get_integer(weights, index, 0)),
              Ops.divide(sum, 2)
            ),
            sum
          )
          if Ops.greater_than(
              Ops.get_integer(ps, [pindex, "size_max_cyl"], 0),
              0
            ) &&
              !Ops.get_boolean(ps, [pindex, "grow"], false) &&
              Ops.greater_than(
                diff,
                Ops.subtract(
                  Ops.get_integer(ps, [pindex, "size_max_cyl"], 0),
                  Ops.get_integer(p, 2, 0)
                )
              )
            diff = Ops.subtract(
              Ops.get_integer(ps, [pindex, "size_max_cyl"], 0),
              Ops.get_integer(p, 2, 0)
            )
          end
          sum = Ops.subtract(sum, Ops.get_integer(weights, index, 0))
          rest = Ops.subtract(rest, diff)
          Ops.set(
            added,
            [index, 2],
            Ops.add(Ops.get_integer(added, [index, 2], 0), diff)
          )
          diff_sum = Ops.add(diff_sum, diff)
          Builtins.y2milestone(
            "sum %1 rest %2 diff %3 added %4",
            sum,
            rest,
            diff,
            Ops.get_list(added, index, [])
          )
        end
        index = Ops.add(index, 1)
      end
      ret = { "added" => added, "diff" => diff_sum }
      Builtins.y2milestone("ret (distribute_space) %1", ret)
      deep_copy(ret)
    end
    def do_weighting(ps, g)
      ps = deep_copy(ps)
      g = deep_copy(g)
      Builtins.y2milestone("do_weighting gap %1", Ops.get_list(g, "gap", []))
      ret = 0
      index = 0
      ret = 0 if @cur_mode == :free
      if @cur_mode == :reuse
        ret = Ops.subtract(ret, 100)
      elsif @cur_mode == :resize
        ret = Ops.subtract(ret, 1000)
      elsif @cur_mode == :desparate
        ret = Ops.subtract(ret, 1000000)
      end
      Builtins.y2milestone("weight after mode ret %1", ret)
      Builtins.foreach(Ops.get_list(g, "gap", [])) do |e|
        Builtins.y2milestone("added %1", Ops.get_list(e, "added", []))
        if !Ops.get_boolean(e, "exists", false) &&
            Ops.greater_than(Ops.get_integer(e, "cylinders", 0), 0)
          ret = Ops.subtract(ret, 5)
          if Ops.less_than(
              Ops.get_integer(e, "cylinders", 0),
              Ops.divide(Ops.get_integer(g, "disk_cyl", 0), 20)
            )
            ret = Ops.subtract(ret, 10)
          end
          Builtins.y2milestone("weight (cyl) %1", ret)
        end
        Builtins.y2milestone("weight after gaps %1", ret)
        Builtins.foreach(Ops.get_list(e, "added", [])) do |p|
          index = Ops.get_integer(p, 0, 0)
          # bnc#613366 - an existing swap partition can accidently be reused
          # if( e["exists"]:false && ps[index,"mount"]:""=="swap" &&
          #     e["swap"]:false )
          # {
          #     ret = ret + 100;
          #     y2milestone( "weight after swap reuse %1", ret );
          # }
          if Ops.greater_than(Ops.get_integer(ps, [index, "want_cyl"], 0), 0)
            diff = Ops.subtract(
              Ops.get_integer(ps, [index, "want_cyl"], 0),
              Ops.get_integer(p, 2, 0)
            )
            normdiff = Ops.divide(
              Ops.multiply(diff, 100),
              Ops.get_integer(p, 2, 0)
            )
            if Ops.less_than(diff, 0)
              normdiff = Ops.unary_minus(normdiff)
            elsif Ops.greater_than(diff, 0)
              normdiff = Ops.divide(normdiff, 10)
            end
            ret = Ops.subtract(ret, normdiff)
            ret = Ops.add(
              ret,
              Ops.divide(
                Ops.multiply(
                  Ops.get_integer(ps, [index, "want_cyl"], 0),
                  Ops.get_integer(g, "cyl_size", 1)
                ),
                100 * 1024 * 1024
              )
            )
            Builtins.y2milestone("after pct parts %1", ret)
          end
          if Ops.get_integer(ps, [index, "size"], 0) == 0
            ret = Ops.add(
              ret,
              Ops.divide(
                Ops.multiply(
                  Ops.get_integer(p, 2, 0),
                  Ops.get_integer(g, "cyl_size", 1)
                ),
                50 * 1024 * 1024
              )
            )
            Builtins.y2milestone("after maximizes parts %1", ret)
          end
          if Ops.greater_than(
              Ops.get_integer(ps, [index, "size_max_cyl"], 0),
              0
            ) &&
              Ops.less_than(
                Ops.get_integer(ps, [index, "size_max_cyl"], 0),
                Ops.get_integer(p, 2, 0)
              )
            diff = Ops.subtract(
              Ops.get_integer(p, 2, 0),
              Ops.get_integer(ps, [index, "size_max_cyl"], 0)
            )
            normdiff = Ops.divide(
              Ops.multiply(diff, 100),
              Ops.get_integer(ps, [index, "size_max_cyl"], 0)
            )
            ret = Ops.subtract(ret, normdiff)
            Builtins.y2milestone("after maximal size %1", ret)
          end
        end
        # if( e["cylinders"]:0 > 0 )
        # {
        #     y2milestone("ret (before rounding): %1", ret);
        #     ret = ret - (e["cylinders"]:0 * g["cyl_size"]:1) / (1024*1024*1024);
        #     y2milestone("weight (after rounding): %1", ret);
        # }
        if e.fetch("extended", false)
          ret -= 1
          ret -= 100 if e.fetch("added",[]).empty?
        else
          index=0
          ps.each do |p|
            if p.key?("partition_nr")
              ad = e.fetch("added",[]).find { |li| li[0]==index }
              if ad && ad[1]!=p["partition_nr"]
                Builtins.y2milestone("do_weighting part num mismatch add:%1 ps:%2", ad, p)
                ret -= 100
              end
            end
            index += 1
          end
          ret -=10 if g.fetch("free_pnr",[]).size<1
        end
      end
      Builtins.y2milestone("do_weighting weight:  %1", ret)
      ret
    end
    def remove_possible_partitions(disk, pm)
      disk = deep_copy(disk)
      pm = deep_copy(pm)
      remove_special_partitions = Ops.get_boolean(
        pm,
        "remove_special_partitions",
        false
      )
      keep_partition_num = Ops.get_list(pm, "keep_partition_num", [])
      keep_partition_id = Ops.get_list(pm, "keep_partition_id", [])
      keep_partition_fsys = Ops.get_list(pm, "keep_partition_fsys", [])

      # Special partitions
      nodelpart = [18, 222, 257]

      # Handle <usepart> which is analog to create=false and partition_nr>0
      Builtins.foreach(Ops.get_list(pm, "partitions", [])) do |p|
        if Ops.get_integer(p, "usepart", 0) != 0
          keep_partition_num = Builtins.add(
            keep_partition_num,
            Ops.get_integer(p, "usepart", 0)
          )
        end
      end

      ret = deep_copy(disk)
      Ops.set(
        ret,
        "partitions",
        Builtins.maplist(Ops.get_list(ret, "partitions", [])) do |p|
          fsid = Ops.get_integer(p, "fsid", 0)
          if (remove_special_partitions || !Builtins.contains(nodelpart, fsid)) &&
              Ops.get_symbol(p, "type", :primary) != :extended &&
              !Builtins.contains(
                keep_partition_num,
                Ops.get_integer(p, "nr", 0)
              ) &&
              !Builtins.contains(keep_partition_id, fsid) &&
              !Builtins.contains(
                keep_partition_fsys,
                Ops.get_symbol(p, "used_fs", :none)
              )
            Ops.set(p, "delete", true)
            if Builtins.haskey(p, "raid_name")
              Ops.set(p, "old_raid_name", Ops.get_string(p, "raid_name", ""))
              p = Builtins.remove(p, "raid_name")
            end
          end
          deep_copy(p)
        end
      )
      max_prim = Partitions.MaxPrimary(Ops.get_string(disk, "label", "msdos"))

      # delete extended if no logical remain
      if Ops.greater_than(
          Builtins.size(Builtins.filter(Ops.get_list(ret, "partitions", [])) do |p|
            Ops.get_symbol(p, "type", :primary) == :extended
          end),
          0
        ) &&
          Builtins.size(Builtins.filter(Ops.get_list(ret, "partitions", [])) do |p|
            Ops.greater_than(Ops.get_integer(p, "nr", 0), max_prim) &&
              !Ops.get_boolean(p, "delete", false)
          end) == 0
        Ops.set(
          ret,
          "partitions",
          Builtins.maplist(Ops.get_list(ret, "partitions", [])) do |p|
            if Ops.get_symbol(p, "type", :primary) == :extended
              Ops.set(p, "delete", true)
            end
            deep_copy(p)
          end
        )
      end
      Builtins.y2milestone("after removal: %1", ret)
      deep_copy(ret)
    end
    def try_resize_windows(disk)
      disk = deep_copy(disk)
      cyl_size = Ops.get_integer(disk, "cyl_size", 1)
      win = {}
      ret = Builtins.eval(disk)

      Ops.set(
        ret,
        "partitions",
        Builtins.maplist(Ops.get_list(ret, "partitions", [])) do |p|
          fsid = Ops.get_integer(p, "fsid", 0)
          if Partitions.IsDosPartition(fsid)
            psize = Ops.multiply(
              Ops.subtract(
                Ops.add(
                  Ops.get_integer(p, ["region", 0], 0),
                  Ops.get_integer(p, ["region", 1], 1)
                ),
                1
              ),
              cyl_size
            )
            win = Storage.GetFreeSpace(
              Ops.get_string(p, "device", ""),
              :fat32,
              false
            )
            Builtins.y2milestone("win=%1", win)
            if win != nil && Ops.greater_than(psize, 300 * 1024 * 1024)
              Ops.set(p, "winfo", win)
              Ops.set(
                p,
                ["region", 1],
                Ops.divide(
                  Ops.subtract(
                    Ops.add(Ops.get_integer(win, "new_size", 0), cyl_size),
                    1
                  ),
                  cyl_size
                )
              )
              Builtins.y2milestone("win part %1", p)
            end
          end
          deep_copy(p)
        end
      )
      deep_copy(ret)
    end





    # Collect gap information
    #
    def get_gaps(start, _end, pd, part, add_exist_linux)
      pd = deep_copy(pd)
      part = deep_copy(part)
      Builtins.y2milestone("partitions: %1", Ops.get_list(pd, "partitions", []))
      usepart_p = Builtins.maplist(Ops.get_list(pd, "partitions", [])) do |pa|
        Ops.get_integer(pa, "usepart", 0)
      end
      reuse = Builtins.filter(usepart_p) { |i| i != 0 }

      Builtins.y2milestone("reuse: %1", reuse)

      Builtins.y2milestone(
        "start %1 end %2 add_exist %3",
        start,
        _end,
        add_exist_linux
      )
      ret = []
      entry = {}
      Builtins.foreach(part) do |p|
        s = Ops.get_integer(p, ["region", 0], 0)
        e = Ops.subtract(Ops.add(s, Ops.get_integer(p, ["region", 1], 1)), 1)
        entry = {}
        Builtins.y2milestone("Getting gap from part: %1", p)
        Builtins.y2milestone("start %1 s %2 e %3", start, s, e)
        if Ops.less_than(start, s)
          Ops.set(entry, "start", start)
          Ops.set(entry, "end", Ops.subtract(s, 1))
          ret = Builtins.add(ret, Builtins.eval(entry))
        end
        if add_exist_linux &&
            (Ops.get_integer(p, "fsid", 0) == Partitions.fsid_native ||
              Ops.get_integer(p, "fsid", 0) == Partitions.fsid_swap)
          Ops.set(
            entry,
            "swap",
            Ops.get_integer(p, "fsid", 0) == Partitions.fsid_swap
          )
          Ops.set(entry, "start", s)
          Ops.set(entry, "end", e)
          Ops.set(entry, "exists", true)
          Ops.set(entry, "nr", Ops.get_integer(p, "nr", 0))
          ret = Builtins.add(ret, entry)
        end
        if Builtins.contains(reuse, Ops.get_integer(p, "nr", 0))
          # This partition is to be used as specified in the control file
          Ops.set(
            entry,
            "swap",
            Ops.get_integer(p, "fsid", 0) == Partitions.fsid_swap
          )
          Ops.set(entry, "start", s)
          Ops.set(entry, "end", e)
          Ops.set(entry, "exists", true)
          Ops.set(entry, "reuse", true)
          Ops.set(entry, "nr", Ops.get_integer(p, "nr", 0))
          ret = Builtins.add(ret, entry)
        end
        start = Ops.add(e, 1)
      end
      if Ops.less_than(start, _end)
        entry = {}
        Ops.set(entry, "start", start)
        Ops.set(entry, "end", _end)
        ret = Builtins.add(ret, entry)
      end
      Builtins.y2milestone("ret %1", ret)
      deep_copy(ret)
    end
    def get_gap_info(disk, pd, add_exist_linux)
      disk = deep_copy(disk)
      pd = deep_copy(pd)
      ret = {}
      gap = []
      plist = Builtins.filter(Ops.get_list(disk, "partitions", [])) do |p|
        !Ops.get_boolean(p, "delete", false)
      end
      plist = Builtins.sort(plist) do |a, b|
        Ops.less_than(
          Ops.get_integer(a, ["region", 0], 0),
          Ops.get_integer(b, ["region", 0], 0)
        )
      end
      exist_pnr = Builtins.sort(Builtins.maplist(plist) do |e|
        Ops.get_integer(e, "nr", 0)
      end)
      max_prim = Partitions.MaxPrimary(Ops.get_string(disk, "label", "msdos"))
      has_ext = Partitions.HasExtended(Ops.get_string(disk, "label", "msdos"))

      # check if we support extended partitions
      if has_ext
        # see if disk has an extended already
        ext = Ops.get(Builtins.filter(plist) do |p|
          Ops.get_symbol(p, "type", :primary) == :extended
        end, 0, {})
        Ops.set(ret, "extended_possible", Builtins.size(ext) == 0)
        if Ops.greater_than(Builtins.size(ext), 0)
          gap = get_gaps(
            Ops.get_integer(ext, ["region", 0], 0),
            Ops.subtract(
              Ops.add(
                Ops.get_integer(ext, ["region", 0], 0),
                Ops.get_integer(ext, ["region", 1], 1)
              ),
              1
            ),
            pd,
            Builtins.filter(plist) do |p|
              Ops.greater_than(Ops.get_integer(p, "nr", 0), max_prim)
            end,
            add_exist_linux
          )
          gap = Builtins.maplist(gap) do |e|
            Ops.set(e, "extended", true)
            deep_copy(e)
          end
          plist = Builtins.filter(plist) do |p|
            Ops.less_or_equal(Ops.get_integer(p, "nr", 0), max_prim)
          end
        end
      else
        Ops.set(ret, "extended_possible", false)
      end

      gap = Convert.convert(
        Builtins.union(
          gap,
          get_gaps(
            0,
            Ops.subtract(Ops.get_integer(disk, "cyl_count", 1), 1),
            pd,
            plist,
            add_exist_linux
          )
        ),
        :from => "list",
        :to   => "list <map>"
      )
      av_size = 0
      gap = Builtins.maplist(gap) do |e|
        Ops.set(
          e,
          "cylinders",
          Ops.add(
            Ops.subtract(
              Ops.get_integer(e, "end", 0),
              Ops.get_integer(e, "start", 0)
            ),
            1
          )
        )
        Ops.set(
          e,
          "size",
          Ops.multiply(
            Ops.get_integer(e, "cylinders", 0),
            Ops.get_integer(disk, "cyl_size", 1)
          )
        )
        av_size = Ops.add(av_size, Ops.get_integer(e, "size", 0))
        deep_copy(e)
      end
      gap = Builtins.maplist(gap) do |e|
        Ops.set(
          e,
          "sizepct",
          Ops.divide(
            Ops.divide(Ops.multiply(Ops.get_integer(e, "size", 0), 201), 2),
            av_size
          )
        )
        Ops.set(e, "sizepct", 1) if Ops.get_integer(e, "sizepct", 0) == 0
        deep_copy(e)
      end
      Ops.set(ret, "cyl_size", Ops.get_integer(disk, "cyl_size", 1))
      Ops.set(ret, "disk_cyl", Ops.get_integer(disk, "cyl_count", 1))
      Ops.set(ret, "max_primary", Ops.get_integer(disk, "max_primary", 0))
      Ops.set(ret, "sum", av_size)
      max_pnr = max_prim
      pnr = 1
      free_pnr = []
      Builtins.y2milestone("exist_pnr %1", exist_pnr)
      while Ops.less_or_equal(pnr, max_pnr)
        if !Builtins.contains(exist_pnr, pnr)
          free_pnr = Builtins.add(free_pnr, pnr)
        end
        pnr = Ops.add(pnr, 1)
      end
      Ops.set(ret, "extended_possible", false) if Builtins.isempty(free_pnr)
      Ops.set(ret, "free_pnr", free_pnr)
      ext_pnr = [
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19,
        20,
        21,
        22,
        23,
        24,
        25,
        26,
        27,
        28,
        29,
        30,
        31,
        32,
        33,
        34,
        35,
        36,
        37,
        38,
        39,
        40,
        41,
        42,
        43,
        44,
        45,
        46,
        47,
        48,
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        58,
        59,
        60,
        61,
        62,
        63
      ]
      max_logical = Ops.get_integer(disk, "max_logical", 15)
      ext_pnr = Builtins.filter(ext_pnr) do |i|
        Ops.less_or_equal(i, max_logical)
      end if Ops.less_than(
        max_logical,
        63
      )
      if !Ops.get_boolean(ret, "extended_possible", false)
        if !has_ext
          ext_pnr = []
        else
          maxext = Ops.get_integer(
            exist_pnr,
            Ops.subtract(Builtins.size(exist_pnr), 1),
            4
          )
          pnr = 5
          while Ops.less_or_equal(pnr, maxext)
            ext_pnr = Builtins.remove(ext_pnr, 0)
            pnr = Ops.add(pnr, 1)
          end
        end
      end
      Ops.set(ret, "ext_pnr", ext_pnr)

      Ops.set(ret, "gap", Builtins.sort(gap) do |a, b|
        Ops.less_than(
          Ops.get_integer(a, "start", 0),
          Ops.get_integer(b, "start", 0)
        )
      end)
      Builtins.y2milestone("ret %1", ret)
      deep_copy(ret)
    end
  end
end
