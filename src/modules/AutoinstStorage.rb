# encoding: utf-8

# File:	modules/AutoinstStorage.ycp
# Module:	Auto-Installation
# Summary:	Storage
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"

module Yast
  class AutoinstStorageClass < Module

    include Yast::Logger

    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.import "Storage"
      Yast.import "RootPart"
      Yast.import "Partitions"
      Yast.import "FileSystems"
      Yast.import "Summary"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "Mode"
      Yast.import "Installation"

      # All shared data are in yast2.rpm to break cyclic dependencies
      Yast.import "AutoinstData"

      # Read existing fstab and format partitions, but dont create anything
      # Use same mountpoints etc.
      @read_fstab = false
      @ZeroNewPartitions = true

      # Fstab options
      @fstab = {}

      # Partition plan as parsed from control file
      @AutoPartPlan = []

      # Prepared target map from parsed data
      @AutoTargetMap = {}

      # default value of settings modified
      @modified = false

      @raid2device = {}

      # some architectures need a boot partition. Do we have one?
      @planHasBoot = false

      # list of devices to ignore when guessing devices
      @tabooDevices = []

      Yast.include self, "autoinstall/autopart.rb"
      Yast.include self, "autoinstall/autoinst_dialogs.rb"
    end

    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      Builtins.y2milestone("SetModified")
      @modified = true

      nil
    end

    # Functions which returns if the settings were modified
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end

    # Wrapper function for the LibStorage call that can't be used directly
    # in YCP
    # @return [Fixnum]
    #
    def humanStringToByte(s, b)
      s = "0b" if Builtins.size(s) == 0
      s = Ops.add(s, "b") if Builtins.findfirstof(s, "bB") == nil
      Storage.ClassicStringToByte(s)
    end

    META_TYPES = [ :CT_DMRAID, :CT_MDPART, :CT_DMMULTIPATH ]
    ALL_TYPES = META_TYPES.dup.push(:CT_DISK)

    def find_next_disk( tm, after, ctype )
      Builtins.y2milestone("find_next_disk after:\"%1\" ctype:%2", after, ctype);
      used_disk = ""
      if after.empty? && !ALL_TYPES.include?(ctype)
        tm.each do |device, disk|
          if META_TYPES.include?(disk.fetch("type")) &&
             !@tabooDevices.include?(device)
            used_disk = device
          end
        end
      end

      if after.empty? && used_disk.empty?
        tm.each do |device, disk|
          if disk["bios_id"]=="0x80" && !@tabooDevices.include?(device)
            used_disk = device
          end
        end
      end

      # device guessing code enhanced
      if used_disk.empty?
        ctype = :CT_DISK  unless ALL_TYPES.include?(ctype)
        disks = tm.select { |dev,disk| disk["type"]==ctype };
        found = !disks.keys.include?(after)
        disks.each do |device, disk|
          next if !found && device != after 
          found = true if device == after
          next if device == after || @tabooDevices.include?(device)
          used_disk = device
          break
        end
      end

      Builtins.y2milestone("find_next_disk device detection: %1", used_disk)
      used_disk
    end

    # Pre-process partition plan and prepare for creating partitions.
    # @return [void]
    def set_devices(storage_config)
      storage_config = deep_copy(storage_config)
      Builtins.y2milestone("entering set_devices with %1", storage_config)
      first_set = false
      failed = false
      auto_targetmap = Builtins.listmap(storage_config) do |drive|
        device = ""
        Builtins.y2milestone("Working on drive: %1", drive)
        # FIXME: Check if physical drives > 1
        if Ops.get_string(drive, "device", "") == "ask"
          dev = DiskSelectionDialog()
          if dev != nil
            first_set = true
            device = dev
          end

          next { device => drive }
        end
        if !first_set &&
            (Ops.get_string(drive, "device", "") == "" ||
              Ops.get_string(drive, "device", "") == "ask")
          device = Storage.GetPartDisk
          Builtins.y2milestone("device: %1", device)
          first_set = true
          next { device => drive }
        elsif Ops.get_string(drive, "device", "") != ""
          dev = Ops.get_string(drive, "device", "")
          if dev == ""
            dev = "error"
            Builtins.y2error("Missing device name in partitioning plan")
            failed = true
          end

          next { dev => drive }
        end
      end

      return nil if failed

      auto_targetmap = Builtins.mapmap(auto_targetmap) do |device, d|
        # Convert from Old Style
        if Builtins.haskey(d, "use")
          Builtins.y2milestone(
            "converting from \"use\" to new style: %1",
            device
          )
          if Ops.get_string(d, "use", "") == "free"
            Ops.set(d, "prefer_remove", false)
          elsif Ops.get_string(d, "use", "") == "all"
            Ops.set(d, "prefer_remove", true)
          elsif Ops.get_string(d, "use", "") == "linux"
            Ops.set(d, "keep_partition_num", GetNoneLinuxPartitions(device))
            Ops.set(d, "prefer_remove", true)
          else
            uselist = Builtins.filter(
              Builtins.splitstring(Ops.get_string(d, "use", ""), ",")
            ) { |s| s != "" }
            Builtins.y2milestone("uselist: %1", uselist)
            keeplist = []
            all = GetAllPartitions(device)
            Builtins.y2milestone("all list: %1", all)
            Builtins.foreach(all) do |i|
              if !Builtins.contains(uselist, Builtins.sformat("%1", i))
                keeplist = Builtins.add(keeplist, i)
              end
            end
            Builtins.y2milestone("keeplist: %1", keeplist)
            Ops.set(d, "keep_partition_num", keeplist)

            if Ops.greater_than(Builtins.size(keeplist), 0)
              Ops.set(d, "prefer_remove", true)
            end
          end
        else
          Ops.set(d, "use", "all")
        end
        # see if <usepart> is used and add the partitions to <keep_partition_num>
        Builtins.foreach(Ops.get_list(d, "partitions", [])) do |p|
          if Ops.get_integer(p, "usepart", -1) != -1
            Ops.set(
              d,
              "keep_partition_num",
              Builtins.add(
                Ops.get_list(d, "keep_partition_num", []),
                Ops.get_integer(p, "usepart", -1)
              )
            )
          end
        end
        Ops.set(
          d,
          "keep_partition_num",
          Builtins.toset(Ops.get_list(d, "keep_partition_num", []))
        )
        { device => d }
      end

      Builtins.y2milestone(
        "processed autoyast partition plan: %1",
        auto_targetmap
      )
      deep_copy(auto_targetmap)
    end

    def GetRaidDevices(dev, tm)
      tm = deep_copy(tm)
      ret = []
      tm.each do |k, d|
        if [:CT_DISK,:CT_DMMULTIPATH].include?(d["type"])
          tmp = d.fetch("partitions",[]).select do |p|
            p["raid_name"]==dev
          end
          ret.concat(tmp)
        end
      end
      dlist = ret.map { |p| p["device"] }
      Builtins.y2milestone("GetRaidDevices dlist = %1 and ret = %2", dlist, ret)
      deep_copy(dlist)
    end

    def SearchRaids(tm)
      tm = deep_copy(tm)
      already_mapped = {}

      #    optional device order for the raid:
      #    <device>/dev/md</device>
      #    <partitions config:type="list">
      #      <partition>
      #        <raid_options>
      #          <device_order config:type="list">
      #             <device>/dev/sdc1</device>
      #             <device>/dev/sdb2</device>
      #          </device_order>
      #        </raid_options>
      #        ...
      d = Ops.get(@AutoTargetMap, "/dev/md", {})
      counter = 0
      Builtins.foreach(Ops.get_list(d, "partitions", [])) do |p|
        if Builtins.haskey(p, "raid_options") &&
            Ops.get_list(p, ["raid_options", "device_order"], []) != []
          counter = Ops.get_integer(p, "partition_nr", counter)
          order = Ops.get_list(p, ["raid_options", "device_order"], [])
	  dev = "/dev/md"+counter.to_s;
	  if p["raid_options"] && p["raid_options"].has_key?("raid_name") &&
	     !p["raid_options"]["raid_name"].empty?
	    dev = p["raid_options"]["raid_name"]
	  end
          Builtins.y2milestone(
            "found device_order %1 in raidoptions for %2", order, dev)
	  @raid2device[dev] = order
	  already_mapped[dev] = true
        end
        counter = Ops.add(counter, 1)
      end
      #raid2device = $[];
      tm.each do |k, d2|
        if [:CT_DISK,:CT_DMMULTIPATH].include?(d2["type"])
          tmp = d2.fetch("partitions",[]).select do |p| 
            !p.fetch("raid_name","").empty?
          end
          devMd = tmp.map { |p| p["raid_name"] }
          devMd.each do |dev|
            next if already_mapped[dev]
            @raid2device[dev] = GetRaidDevices(dev, tm)
          end
        end
      end
      Builtins.y2milestone("SearchRaids raid2device = %1", @raid2device)

      nil
    end

    # if mountby is used, we will search for the matching
    # partition here.
    # @return [Array]
    def mountBy(settings)
      settings = deep_copy(settings)
      tm = Storage.GetTargetMap
      Builtins.y2milestone("Storage::GetTargetMap returns %1", tm)
      settings = Builtins.maplist(settings) do |d|
        device = Ops.get_string(d, "device", "")
        Ops.set(
          d,
          "partitions",
          Builtins.maplist(Ops.get_list(d, "partitions", [])) do |p|
            mountby = ""
            mountByIsList = false
            if Ops.get_string(p, "mount", "") == "swap" ||
                Ops.get_symbol(p, "filesystem", :none) == :swap
              Ops.set(p, "mount", "swap")
              Ops.set(p, "filesystem", :swap)
            end
            if Builtins.haskey(p, "mountby")
              if Ops.get_symbol(p, "mountby", :none) == :label
                mountby = "label"
              elsif Ops.get_symbol(p, "mountby", :none) == :uuid
                mountby = "uuid"
              elsif Ops.get_symbol(p, "mountby", :none) == :path
                mountby = "udev_path"
              elsif Ops.get_symbol(p, "mountby", :none) == :id
                mountByIsList = true
                mountby = "udev_id"
              elsif Ops.get_symbol(p, "mountby", :none) != :device
                Builtins.y2milestone(
                  "unknown mountby parameter '%1' will be ignored",
                  Ops.get_symbol(p, "mountby", :none)
                )
              end
            end
            # reuse partition by "mountby"
            if mountby != "" && Ops.get_boolean(p, "create", true) == false &&
                !Builtins.haskey(p, "partition_nr")
              label = Ops.get_string(p, mountby, "")
              Builtins.y2milestone(
                "mountby found for %1=%2 in part=%3",
                mountby,
                label,
                p
              )
              target = Ops.get(tm, device, {})
              if device == ""
                Builtins.y2milestone("searching for the device by %1", mountby)
                Builtins.foreach(tm) do |deviceName, tmp_target|
                  Builtins.foreach(Ops.get_list(tmp_target, "partitions", [])) do |targetPart|
                    if mountByIsList ?
                        Builtins.contains(
                          Ops.get_list(targetPart, mountby, []),
                          label
                        ) :
                        Ops.get_string(targetPart, mountby, "") == label
                      target = deep_copy(tmp_target)
                      device = deviceName
                      Builtins.y2milestone("device=%1 found", device)
                      raise Break
                    end
                  end
                end
              end
              Builtins.foreach(Ops.get_list(target, "partitions", [])) do |targetPart|
                if mountByIsList ?
                    Builtins.contains(
                      Ops.get_list(targetPart, mountby, []),
                      label
                    ) :
                    Ops.get_string(targetPart, mountby, "") == label
                  Builtins.y2milestone("%1 found in targetmap", mountby)
                  Ops.set(d, "device", device) #FIXME: for some reason this does not work
                  Ops.set(
                    p,
                    "partition_nr",
                    Ops.get_integer(targetPart, "nr", 0)
                  )
                  Ops.set(p, "usepart", Ops.get_integer(targetPart, "nr", 0))
                end
              end
            end
            deep_copy(p)
          end
        )
        deep_copy(d)
      end
      Builtins.y2milestone("after mountBy settings=%1", settings)
      deep_copy(settings)
    end

    # makes something like:
    #         <device>/dev/disk/by-id/edd-int13_dev80</device>
    #    possible (Bug #82867)
    def udev2dev(settings)
      settings = deep_copy(settings)
      tm = Storage.GetTargetMap
      last_dev = ""
      settings = Builtins.maplist(settings) do |d|
        device = Ops.get_string(d, "device", "")
        udev_string = ""
        if device == ""
          dtyp = d.fetch("type",:CT_UNKNOWN)
          d["device"] = find_next_disk(tm,last_dev,dtyp)
          Builtins.y2milestone(
            "empty device in profile set to %1", d["device"] )
        end
        # translation of by-id, by-path, ... device names.
        # was handled in autoyast until openSUSE 11.3
        deviceTranslation = {}
        if (
            deviceTranslation_ref = arg_ref(deviceTranslation);
            _GetContVolInfo_result = Storage.GetContVolInfo(
              Ops.get_string(d, "device", ""),
              deviceTranslation_ref
            );
            deviceTranslation = deviceTranslation_ref.value;
            _GetContVolInfo_result
          )
          Ops.set(d, "device", Ops.get_string(deviceTranslation, "cdevice", ""))
        end
        last_dev = Ops.get_string(d, "device", "")
        deep_copy(d)
      end
      deep_copy(settings)
    end

    def checkSizes(settings)
      settings = deep_copy(settings)
      Builtins.y2milestone("entering checkSizes with %1", settings)
      tm = Storage.GetTargetMap
      Builtins.y2milestone("targetmap = %1", tm)

      settings = Builtins.maplist(settings) do |d|
        if Ops.get_symbol(d, "type", :x) == :CT_DISK
          sizeByCyl = 0
          usedSize = 0
          max = 0
          cyl_size = 0
          Builtins.foreach(tm) do |device, v|
            if device == Ops.get_string(d, "device", "")
              sizeByCyl = Ops.multiply(
                Ops.get_integer(v, "cyl_count", 0),
                Ops.get_integer(v, "cyl_size", 0)
              )
              cyl_size = Ops.get_integer(v, "cyl_size", 0)
              Builtins.y2milestone(
                "device found in tm. sizeByCyl=%1",
                sizeByCyl
              )
            end
          end
          if sizeByCyl == 0
            Builtins.y2milestone("not found")
            next deep_copy(d)
          end
          Builtins.foreach(Ops.get_list(d, "partitions", [])) do |pe|
            usedSize = Ops.add(usedSize, Ops.get_integer(pe, "size", 0))
            if Ops.greater_than(Ops.get_integer(pe, "size", 0), max)
              max = Ops.get_integer(pe, "size", 0)
            end
          end
          if Ops.greater_than(usedSize, sizeByCyl)
            Builtins.y2milestone("usedSize too big: %1", usedSize)
            Ops.set(
              d,
              "partitions",
              Builtins.maplist(Ops.get_list(d, "partitions", [])) do |pe|
                s = Ops.get_integer(pe, "size", 0)
                if s == max
                  Builtins.y2milestone("shrinking %1", pe)
                  s = Ops.subtract(
                    s,
                    Ops.multiply(
                      Ops.add(
                        Ops.add(
                          Ops.divide(
                            Ops.subtract(usedSize, sizeByCyl),
                            cyl_size
                          ),
                          1
                        ),
                        Builtins.size(Ops.get_list(d, "partitions", []))
                      ),
                      cyl_size
                    )
                  ) # 1 cyl buffer per partition
                  if Ops.less_than(s, 1)
                    Report.Error(
                      Builtins.sformat(
                        _(
                          "The partition plan configured in your XML profile does not fit on the hard disk. %1MB missing"
                        ),
                        Ops.divide(
                          Ops.subtract(usedSize, sizeByCyl),
                          1024 * 1024
                        )
                      )
                    )
                    raise Break
                  else
                    usedSize = Ops.subtract(usedSize, s)
                    Builtins.y2milestone("shrinking to %1", s)
                    Ops.set(pe, "size", s)
                  end
                end
                deep_copy(pe)
              end
            )
          end
        end
        deep_copy(d)
      end
      Builtins.y2milestone("after checkSizes %1", settings)
      deep_copy(settings)
    end

    #    the resize option in the storage lib requires the new size in the
    #    "region" format. That format is hardly configureable by humans, so I
    #    do the translation here
    def region4resize(settings)
      settings = deep_copy(settings)
      # the storage lib requires the region to be set
      # we transform the size to the region here
      tm = Storage.GetTargetMap
      settings = Builtins.maplist(settings) do |d|
        if Ops.get_symbol(d, "type", :x) == :CT_DISK
          realDisk = Ops.get(tm, Ops.get_string(d, "device", ""), {})
          Ops.set(
            d,
            "partitions",
            Builtins.maplist(Ops.get_list(d, "partitions", [])) do |pe|
              if Ops.get_boolean(pe, "resize", false)
                currentCyl = Ops.get_integer(
                  realDisk,
                  [
                    "partitions",
                    Ops.subtract(Ops.get_integer(pe, "partition_nr", 1), 1),
                    "region",
                    1
                  ],
                  0
                )
                Ops.set(
                  pe,
                  "region",
                  Ops.get_list(
                    realDisk,
                    [
                      "partitions",
                      Ops.subtract(Ops.get_integer(pe, "partition_nr", 1), 1),
                      "region"
                    ],
                    []
                  )
                )
                if Builtins.issubstring(Ops.get_string(pe, "size", ""), "%")
                  percentage = Builtins.deletechars(
                    Ops.get_string(pe, "size", ""),
                    "%"
                  )
                  newCyl = Ops.divide(
                    Ops.multiply(currentCyl, Builtins.tointeger(percentage)),
                    100
                  )
                  Ops.set(pe, ["region", 1], newCyl)
                else
                  new_size = humanStringToByte(
                    Ops.get_string(pe, "size", "0"),
                    true
                  )
                  newCyl = Ops.divide(
                    new_size,
                    Ops.get_integer(realDisk, "cyl_size", 1)
                  )
                  Ops.set(pe, ["region", 1], newCyl)
                end
                Builtins.y2milestone(
                  "resize partition nr %1 of %2 to region: %3",
                  Ops.get_integer(pe, "partition_nr", 1),
                  Ops.get_string(d, "device", ""),
                  Ops.get_list(pe, "region", [])
                )
              end
              deep_copy(pe)
            end
          )
        end
        deep_copy(d)
      end
      Builtins.y2milestone("after region4resize = %1", settings)
      deep_copy(settings)
    end

    #     the percentage must be calculated to an actual size.
    #     This is done here
    def percent2size(settings)
      settings = deep_copy(settings)
      tm = Storage.GetTargetMap
      settings = Builtins.maplist(settings) do |d|
        if Ops.get_symbol(d, "type", :x) == :CT_DISK
          v = Ops.get(tm, Ops.get_string(d, "device", ""), {})
          Ops.set(
            d,
            "partitions",
            Builtins.maplist(Ops.get_list(d, "partitions", [])) do |pe|
              if Builtins.issubstring(Ops.get_string(pe, "size", ""), "%")
                percentage = Builtins.deletechars(
                  Ops.get_string(pe, "size", ""),
                  "%"
                )
                device_size = Ops.multiply(
                  Ops.get_integer(v, "cyl_count", 0),
                  Ops.get_integer(v, "cyl_size", 0)
                )
                Ops.set(
                  pe,
                  "size",
                  Builtins.sformat(
                    "%1",
                    Ops.divide(
                      Ops.multiply(device_size, Builtins.tointeger(percentage)),
                      100
                    )
                  )
                )
                Builtins.y2milestone(
                  "percentage %1 of %2 = %3",
                  percentage,
                  Ops.get_string(d, "device", ""),
                  Ops.get_string(pe, "size", "")
                )
              end
              deep_copy(pe)
            end
          )
        elsif Ops.get_symbol(d, "type", :x) == :CT_LVM
          Ops.set(
            d,
            "partitions",
            Builtins.maplist(Ops.get_list(d, "partitions", [])) do |pe|
              if Builtins.issubstring(Ops.get_string(pe, "size", ""), "%")
                Ops.set(
                  pe,
                  "size",
                  Builtins.deletechars(Ops.get_string(pe, "size", ""), "%")
                ) # a size smalle than 101 will be treated as % later
              end
              deep_copy(pe)
            end
          )
        end
        deep_copy(d)
      end
      Builtins.y2milestone("after percent2size = %1", settings)
      deep_copy(settings)
    end

    #     if partition type is primary but not set in the profile, set it now
    def setPartitionType(settings)
      settings = deep_copy(settings)
      tm = Storage.GetTargetMap
      settings = Builtins.maplist(settings) do |d|
        if Ops.get_symbol(d, "type", :x) == :CT_DISK
          mp = Ops.get_integer(
            tm,
            [Ops.get_string(d, "device", "xxx"), "max_primary"],
            0
          )
          if Ops.greater_than(mp, 0)
            Ops.set(
              d,
              "partitions",
              Builtins.maplist(Ops.get_list(d, "partitions", [])) do |pe|
                if Builtins.haskey(pe, "partition_nr") &&
                    !Builtins.haskey(pe, "partition_type") &&
                    Ops.less_or_equal(
                      Ops.get_integer(pe, "partition_nr", -1),
                      mp
                    )
                  Ops.set(pe, "partition_type", "primary")
                end
                deep_copy(pe)
              end
            )
          end
        end
        deep_copy(d)
      end
      Builtins.y2milestone("after setPartitionType = %1", settings)
      deep_copy(settings)
    end


    # Get all the configuration from a map.
    # When called by inst_auto<module name> (preparing autoinstallation data)
    # the list may be empty.
    # @param [Array<Hash>] settings a list	[...]
    # @return	[Boolean] success
    def Import(settings)
      settings = deep_copy(settings)
      Builtins.y2milestone("entering Import with %1", settings)
      if Mode.autoinst
        settings = Builtins.maplist(settings) do |d|
          d["partitions"] = d.fetch("partitions",[]).sort do |x, y|
            x.fetch("partition_nr",99)<=>y.fetch("partition_nr",99)
          end
          # snapshots are default
          d["enable_snapshots"] = true unless d.has_key?("enable_snapshots") 
          deep_copy(d)
        end

        # fill tabooDevice list with devices to ignore
        initial_target_map = Storage.GetTargetMap
        Builtins.foreach(settings) do |drive|
          if Ops.get_string(drive, "device", "") != ""
            # if <device> is set, it can not end in the taboo list
            next
          end
          # XML example
          # <drive>
          #   <skip_list config:type="list">
          #     <listentry>
          #       <skip_key>driver</skip_key>
          #       <skip_value>usb-storage</skip_value>
          #     </listentry>
          #     <listentry>
          #       <skip_key>size_k</skip_key>
          #       <skip_value>1048576</skip_value>
          #       <skip_if_less_than config:type="boolean">true</skip_if_less_than>
          #     </listentry>
          #   </skip_list>
          #   ...
          Builtins.foreach(initial_target_map) do |device, disk|
            Builtins.foreach(Ops.get_list(drive, "skip_list", [])) do |toSkip|
              skipKey = Ops.get_string(toSkip, "skip_key", "__missing_key__")
              if Ops.is_string?(Ops.get(disk, skipKey))
                skipValue = Ops.get_string(toSkip, "skip_value", "__missing__")
                if Ops.get_string(disk, skipKey, "__not_found__") == skipValue
                  @tabooDevices = Builtins.add(@tabooDevices, device)
                  Builtins.y2milestone(
                    "%1 added to device taboo list (%2 == %3)",
                    device,
                    skipKey,
                    skipValue
                  )
                  raise Break
                end
              elsif Ops.is_integer?(Ops.get(disk, skipKey))
                skipValue = Builtins.tointeger(
                  Ops.get_string(toSkip, "skip_value", "0")
                )
                skipValueLess = Ops.get_boolean(
                  toSkip,
                  "skip_if_less_than",
                  false
                )
                skipValueMore = Ops.get_boolean(
                  toSkip,
                  "skip_if_more_than",
                  false
                )
                skipValueEqual = Ops.get_boolean(toSkip, "skip_if_equal", true)
                if skipValueLess &&
                    Ops.less_than(Ops.get_integer(disk, skipKey, 0), skipValue)
                  @tabooDevices = Builtins.add(@tabooDevices, device)
                  Builtins.y2milestone(
                    "%1 added to device taboo list (%2 < %3)",
                    device,
                    Ops.get_integer(disk, skipKey, 0),
                    skipValue
                  )
                elsif skipValueMore &&
                    Ops.greater_than(
                      Ops.get_integer(disk, skipKey, 0),
                      skipValue
                    )
                  @tabooDevices = Builtins.add(@tabooDevices, device)
                  Builtins.y2milestone(
                    "%1 added to device taboo list (%2 > %3)",
                    device,
                    Ops.get_integer(disk, skipKey, 0),
                    skipValue
                  )
                end
                if skipValueEqual &&
                    Ops.get_integer(disk, skipKey, 0) == skipValue
                  @tabooDevices = Builtins.add(@tabooDevices, device)
                  Builtins.y2milestone(
                    "%1 added to device taboo list (%2 == %3)",
                    device,
                    skipKey,
                    skipValue
                  )
                  raise Break
                end
              elsif Ops.is_symbol?(Ops.get(disk, skipKey))
                skipValue = Ops.get_string(toSkip, "skip_value", "`nothing")
                if Builtins.sformat(
                    "%1",
                    Ops.get_symbol(disk, skipKey, :nothing)
                  ) == skipValue
                  @tabooDevices = Builtins.add(@tabooDevices, device)
                  Builtins.y2milestone(
                    "%1 added to device taboo list (%2 == %3)",
                    device,
                    skipKey,
                    skipValue
                  )
                  raise Break
                end
              else
                Builtins.y2error(
                  "skipKey '%1' is of unknown type. Will be ignored.",
                  skipKey
                )
              end
            end
          end
        end

        settings = udev2dev(settings)
        settings = mountBy(settings)
        settings = region4resize(settings)
        settings = percent2size(settings)
        settings = setPartitionType(settings)
        settings = Builtins.maplist(settings) do |d|
          Ops.set(
            d,
            "partitions",
            Builtins.maplist(Ops.get_list(d, "partitions", [])) do |pe|
              if Builtins.haskey(pe, "size")
                if (Ops.get_string(pe, "size", "") == "auto" ||
                    Ops.get_string(pe, "size", "") == "suspend") &&
                    Ops.get_string(pe, "mount", "") == "swap"
                  Ops.set(
                    pe,
                    "size",
                    Builtins.sformat(
                      "%1",
                      Ops.multiply(
                        1024 * 1024,
                        Partitions.SwapSizeMb(
                          0,
                          Ops.get_string(pe, "size", "") == "suspend"
                        )
                      )
                    )
                  )
                elsif Ops.get_string(pe, "size", "") == "auto" &&
                      ( Ops.get_string(pe, "mount", "") == "/boot" ||
                        Partitions.IsPrepPartition(pe.fetch("partition_id", 0)) )
                  Ops.set(
                    pe,
                    "size",
                    Builtins.sformat("%1", Partitions.MinimalNeededBootsize)
                  )
                end
                if !["max","auto"].include?(pe["size"].downcase)
                  Ops.set(
                    pe,
                    "size",
                    Builtins.sformat(
                      "%1",
                      humanStringToByte(Ops.get_string(pe, "size", ""), false)
                    )
                  )
                end
              end
              deep_copy(pe)
            end
          )
          deep_copy(d)
        end
        @AutoPartPlan = preprocess_partition_config(settings)
        @AutoPartPlan = checkSizes(@AutoPartPlan)
      else
        settings = Builtins.maplist(settings) do |d|
          if !Builtins.haskey(d, "device")
            # this is just to satisfy the UI
            d = Builtins.add(d, "device", "auto")
            Builtins.y2debug("device 'auto' added")
          end
          deep_copy(d)
        end
        @AutoPartPlan = deep_copy(settings)
      end
      Builtins.y2milestone("AutoPartPlan: %1", @AutoPartPlan)

      true
    end

    # Import Fstab data
    # @param [Hash] settings Settings Map
    # @return	[Boolean] true on success
    def ImportAdvanced(settings)
      settings = deep_copy(settings)
      Builtins.y2milestone("entering ImportAdvanced with %1", settings)
      @fstab = Ops.get_map(settings, "fstab", {})
      @read_fstab = Ops.get_boolean(@fstab, "use_existing_fstab", false)

      #AutoinstLVM::ZeroNewPartitions = settings["zero_new_partitions"]:true;
      true
    end

    # return Summary of configuration
    # @return  [String] configuration summary dialog
    def Summary
      summary = ""
      summary = Summary.AddHeader(summary, _("Drives"))
      num = Builtins.size(@AutoPartPlan)
      summary = Summary.AddLine(
        summary,
        Builtins.sformat(_("Total of %1 drive"), num)
      )
      summary = Summary.OpenList(summary)
      Builtins.foreach(@AutoPartPlan) do |drive|
        summary = Summary.AddListItem(
          summary,
          Ops.get_locale(drive, "device", _("No specific device configured"))
        )
      end
      summary = Summary.CloseList(summary)
      summary
    end

    # Moved here from RootPart module (used just by this module)
    def SetFormatPartitions(fstabpart)
      fstabpart = deep_copy(fstabpart)
      # All storage devices
      target_map = Storage.GetTargetMap

      # all activated
      tmp = Builtins.filter(RootPart.GetActivated) do |e|
        Ops.get_string(e, :type, "") == "mount" ||
          Ops.get_string(e, :type, "") == "swap"
      end

      Builtins.foreach(tmp) do |e|
        mntpt = Ops.get_string(e, :type, "") == "swap" ?
          "swap" :
          Ops.get_string(e, :mntpt, "")
        part = Ops.get_string(e, :device, "")
        p = {}
        Builtins.foreach(fstabpart) do |pp|
          # mountpoint matches
          if Ops.get_string(pp, "mount", "") == mntpt
            p = deep_copy(pp)
            raise Break
          end
        end
        mount_options = ""
        Builtins.foreach(Storage.ReadFstab(Installation.destdir)) do |entry|
          if Ops.get_string(entry, "file", "") == mntpt
            mount_options = Ops.get_string(entry, "mntops", "")
            raise Break
          end
        end
        target_map = Storage.SetPartitionData(target_map, part, "mount", mntpt)
        target_map = Storage.SetPartitionData(
          target_map,
          part,
          "format",
          Ops.get_boolean(p, "format", false)
        )
        target_map = Storage.SetPartitionData(target_map, part, "delete", false)
        target_map = Storage.SetPartitionData(target_map, part, "create", false)
        if Builtins.haskey(p, "filesystem")
          target_map = Storage.SetPartitionData(
            target_map,
            part,
            "filesystem",
            Ops.get_symbol(p, "filesystem", :ext4)
          )
        end
        if Ops.greater_than(Builtins.size(mount_options), 0) &&
            !Builtins.haskey(p, "fstopt")
          target_map = Storage.SetPartitionData(
            target_map,
            part,
            "fstopt",
            mount_options
          )
        end
        if Builtins.haskey(p, "fstopt")
          target_map = Storage.SetPartitionData(
            target_map,
            part,
            "fstopt",
            Ops.get_string(p, "fstopt", "")
          )
        end
        if Builtins.haskey(p, "mountby")
          target_map = Storage.SetPartitionData(
            target_map,
            part,
            "mountby",
            Ops.get_symbol(p, "mountby", :device)
          )
        end
      end

      Storage.SetTargetMap(target_map)
      true
    end

    # Handle /etc/fstab usage
    # @return [Boolean]
    def handle_fstab
      Builtins.y2milestone("entering handle_fstab")

      if !RootPart.didSearchForRootPartitions
        UI.OpenDialog(
          Opt(:decorated),
          Label(_("Evaluating root partition. One moment please..."))
        )
        RootPart.FindRootPartitions
        UI.CloseDialog
      end

      if RootPart.numberOfValidRootPartitions == 0
        # a popup
        Popup.Message(_("No Linux root partition found."))
        return false
      end

      # We must only change RootPart::selectedRootPartition if booting
      # is inevitable.
      rp = Ops.get_string(@fstab, "root_partition", "")
      fstab_partitions = Ops.get_list(@fstab, "partitions", [])

      if RootPart.numberOfValidRootPartitions == 1
        RootPart.SetSelectedToValid
      elsif rp == ""
        Popup.Message(
          _(
            "Multiple root partitions found, but you did not configure\nwhich root partition should be used.  Automatic installation not possible.\n"
          )
        )
        return false
      elsif Builtins.haskey(RootPart.rootPartitions, rp) &&
          Ops.greater_than(RootPart.numberOfValidRootPartitions, 1)
        RootPart.selectedRootPartition = rp
      end

      RootPart.MountPartitions(RootPart.selectedRootPartition)
      SetFormatPartitions(fstab_partitions)
      RootPart.UnmountPartitions(true)
      true
    end


    # Create partition plan
    # @return [Boolean]
    def Write
      Builtins.y2milestone("entering Write")
      Storage.SetRecursiveRemoval(true)

      return handle_fstab if @read_fstab

      initial_target_map = Storage.GetTargetMap
      Builtins.y2milestone("Target map: %1", initial_target_map)

      Storage.SetPartDisk(find_next_disk(initial_target_map,"",:CT_DISK))

      @AutoTargetMap = set_devices(@AutoPartPlan)
      return false if @AutoTargetMap == nil || @AutoTargetMap == {}

      Builtins.y2milestone("AutoTargetMap: %1", @AutoTargetMap)

      # return list of available devices
      disk_devices = initial_target_map.select do |l, f|
	Storage.IsRealDisk(f)
	end.keys
      Builtins.y2milestone("disk_devices: %1", disk_devices)

      result = false
      changed = false
      Builtins.foreach(@AutoTargetMap) do |device, data|
        if Storage.IsPartitionable(data) && data.fetch("initialize", false)
          Ops.set(initial_target_map, [device, "delete"], true)
	  changed = true
          if data.has_key?("disklabel")
            Ops.set(
              initial_target_map,
              [device, "disklabel"],
	      data.fetch("disklabel", "msdos")
            )
          end
        end
      end
      if changed
	Storage.SetTargetMap(initial_target_map)
	Builtins.y2milestone( "Target map after initializing disk: %1", Storage.GetTargetMap)
      end

      Builtins.foreach(@AutoTargetMap) do |device, data|
	dlabel = data.fetch("label", "")
        if Ops.greater_than(
            Builtins.size(Builtins.filter(data.fetch("partitions",[])) do |e|
              e.fetch("mount","") == Partitions.BootMount ||
                e.fetch("partition_id",0) == Partitions.FsidBoot(dlabel) &&
                  Partitions.FsidBoot(dlabel) != 131
            end),
            0
          )
          @planHasBoot = true
          raise Break
        end
      end
      Builtins.y2milestone("plan has boot: %1", @planHasBoot)

      tm = Storage.GetTargetMap
      changed = false
      Builtins.foreach(@AutoTargetMap) do |device, data|
        if !tm.has_key?(device) && data.fetch("type",:CT_DISK)==:CT_DISK
          Report.Error(
            Builtins.sformat(
              _("device '%1' not found by storage backend"),
              device
            )
          )
          Builtins.y2milestone("device %1 not found in TargetMap", device)
        end
        if Storage.IsPartitionable(data)
          @ZeroNewPartitions = data.fetch("zero_new_partitions",true)
          # that's not really nice. Just an undocumented fallback which should never be used
          Builtins.y2milestone("Creating partition plans for %1", device)

          sol = find_matching_disk([device], tm, data)
          result = true if sol.size>0

          Builtins.y2milestone("solutions: %1", sol)
          Builtins.y2milestone("disk: %1", tm[device])
	  tm[device] = process_partition_data(device, sol)

          if data["enable_snapshots"] && tm[device].has_key?("partitions")
            root_partition = tm[device]["partitions"].find{|p| p["mount"] == "/" && p["used_fs"] == :btrfs}
            if root_partition
              log.debug("Enabling snapshots for \"/\"; device #{data['device']}")
              root_partition["userdata"] = { "/" => "snapshots" }
            end
          end

	  changed = true
          SearchRaids(tm)
          Builtins.y2milestone("disk: %1", tm[device])
        end
      end
      Storage.SetTargetMap(tm) if changed

      changed = false
      tmpfs_device = @AutoTargetMap["/dev/tmpfs"]
      if tmpfs_device && tmpfs_device.has_key?("partitions")
        # Adding TMPFS
        tmpfs_device["partitions"].each do |partition|
          Storage.AddTmpfsVolume(partition["mount"], partition["fstopt"] || "")
          changed = true
        end
      end
      log.info("Target map after setting tmpfs: #{Storage.GetTargetMap}") if changed

      if Builtins.haskey(@AutoTargetMap, "/dev/nfs")
        Builtins.y2milestone("nfs:%1", Ops.get(@AutoTargetMap, "/dev/nfs", {}))
        Builtins.foreach(
          Ops.get_list(@AutoTargetMap, ["/dev/nfs", "partitions"], [])
        ) do |p|
          sizek = Storage.CheckNfsVolume(
            Ops.get_string(p, "device", ""),
            Ops.get_string(p, "fstopt", ""),
            Ops.get_boolean(p, "nfs4", false)
          )
          Builtins.y2milestone("nfs size:%1", sizek)
          ok = Storage.AddNfsVolume(
            Ops.get_string(p, "device", ""),
            Ops.get_string(p, "fstopt", ""),
            sizek,
            Ops.get_string(p, "mount", ""),
            Ops.get_boolean(p, "nfs4", false)
          )
          Builtins.y2milestone("nfs ok:%1", ok)
          Storage.ChangeVolumeProperties(p) if ok
          result = ok && Ops.get_string(p, "mount", "") == "/" if !result
        end
        Builtins.y2milestone("nfs result:%1", result)
      end

      result
    end


    # Build the id for a partition entry in the man table.
    # @parm disk_dev_name name of the devie e.g.: /dev/hda
    # @parm nr number of the partition e.g.: 1
    # @return [String] e.g.: 01./dev/hda
    def build_id(disk_dev_name, nr)
      nr = deep_copy(nr)
      Builtins.sformat("%1:%2", disk_dev_name, nr)
    end


    # Partitioning Overview
    # @return [Array] Overview
    def Overview
      Builtins.y2milestone("entering Overview")

      allfs = FileSystems.GetAllFileSystems(true, true, "")
      drives_table = []

      id = ""
      Builtins.foreach(@AutoPartPlan) do |d|
        id = Ops.get_string(d, "device", "")
        a = Item(Id(id), Ops.get_string(d, "device", ""), "", "", "", "", "")
        drives_table = Builtins.add(drives_table, a)
        partitions = Ops.get_list(d, "partitions", [])
        start_id = 1
        if Ops.greater_than(Builtins.size(partitions), 0)
          Builtins.foreach(partitions) do |p|
            id = build_id(Ops.get_string(d, "device", ""), start_id)
            b = Item(Id(id))
            b = Builtins.add(b, "")
            b = Builtins.add(b, Ops.get_string(p, "mount", ""))
            b = Builtins.add(b, Ops.get_string(p, "size", ""))
            if !Builtins.haskey(p, "filesystem_id")
              b = Builtins.add(
                b,
                Partitions.FsIdToString(Ops.get_integer(p, "partition_id", 131))
              )
            else
              b = Builtins.add(
                b,
                Partitions.FsIdToString(
                  Ops.get_integer(p, "filesystem_id", 131)
                )
              )
            end
            fs = Ops.get_map(
              allfs,
              Ops.get_symbol(p, "filesystem", :nothing),
              {}
            )
            fs_name = Ops.get_string(fs, :name, "")
            b = Builtins.add(b, fs_name)
            if Ops.greater_than(Builtins.size(Ops.get_list(p, "region", [])), 0)
              b = Builtins.add(
                b,
                Builtins.sformat(
                  "%1 - %2",
                  Ops.get_integer(p, ["region", 0], 0),
                  Ops.get_integer(p, ["region", 1], 0)
                )
              )
            else
              b = Builtins.add(b, "")
            end
            drives_table = Builtins.add(drives_table, b)
            start_id = Ops.add(start_id, 1)
          end
        end
      end

      entries = Builtins.size(drives_table)
      reversed_table = []
      counter = entries

      tmp = Item(Id(:empty))

      while counter != 0
        reversed_table = Builtins.add(
          reversed_table,
          Ops.get_term(drives_table, Ops.subtract(counter, 1), tmp)
        )
        counter = Ops.subtract(counter, 1)
      end
      Builtins.y2debug("table: %1", drives_table)
      deep_copy(drives_table)
    end

    publish :variable => :read_fstab, :type => "boolean"
    publish :variable => :ZeroNewPartitions, :type => "boolean"
    publish :variable => :fstab, :type => "map"
    publish :variable => :AutoPartPlan, :type => "list <map>"
    publish :variable => :AutoTargetMap, :type => "map <string, map>"
    publish :variable => :modified, :type => "boolean"
    publish :variable => :raid2device, :type => "map <string, list>"
    publish :variable => :planHasBoot, :type => "boolean"
    publish :variable => :tabooDevices, :type => "list <string>"
    publish :function => :SetModified, :type => "void ()"
    publish :function => :GetModified, :type => "boolean ()"
    publish :function => :humanStringToByte, :type => "integer (string, boolean)"
    publish :function => :AddFilesysData, :type => "map (map, map)"
    publish :function => :find_next_disk, :type => "string (map,string,symbol)"
    publish :function => :GetRaidDevices, :type => "list (string, map <string, map>)"
    publish :function => :SearchRaids, :type => "void (map <string, map>)"
    publish :function => :mountBy, :type => "list <map> (list <map>)"
    publish :function => :udev2dev, :type => "list <map> (list <map>)"
    publish :function => :checkSizes, :type => "list <map> (list <map>)"
    publish :function => :region4resize, :type => "list <map> (list <map>)"
    publish :function => :percent2size, :type => "list <map> (list <map>)"
    publish :function => :setPartitionType, :type => "list <map> (list <map>)"
    publish :function => :Import, :type => "boolean (list <map>)"
    publish :function => :ImportAdvanced, :type => "boolean (map)"
    publish :function => :Summary, :type => "string ()"
    publish :function => :SetFormatPartitions, :type => "boolean (list <map>)"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Overview, :type => "list ()"
  end

  AutoinstStorage = AutoinstStorageClass.new
  AutoinstStorage.main
end
