# encoding: utf-8

# File:	modules/AutoinstRAID.ycp
# Module:	Auto-Installation
# Summary:	RAID
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"

module Yast
  class AutoinstRAIDClass < Module
    def main
      textdomain "autoinst"

      Yast.import "Storage"
      Yast.import "Partitions"
      Yast.import "AutoinstStorage"

      Yast.include self, "partitioning/raid_lib.rb"


      @ExistingRAID = {}

      @old_available = false



      @raid = {}

      # Local variables
      @region = [0, 0]

      # Temporary copy of variable from Storage
      @targetMap = {}
      AutoinstRAID()
    end

    # Constructor
    # @return [void]
    def AutoinstRAID
      nil
    end

    # Initialize
    def Init
      @raid = Builtins.filter(AutoinstStorage.AutoTargetMap) do |k, v|
        k == "/dev/md"
      end

      return false if Builtins.size(@raid) == 0

      @ExistingRAID = Builtins.filter(Storage.GetTargetMap) do |k, v|
        k == "/dev/md"
      end
      Builtins.y2milestone("Existing RAID: %1", @ExistingRAID)

      @old_available = true if Ops.greater_than(Builtins.size(@ExistingRAID), 0)

      true
    end

    # Return existing MDs
    # @return [Array] list of existing MDs
    def ExistingMDs(md)
      Builtins.filter(get_possible_rds(Storage.GetTargetMap)) do |part|
        Ops.get_string(part, "raid_name", "-1") == md
      end
    end


    # Return deleted MDs
    # @return [Array] list of deleted MDs

    # useless
    #     global define list DeletedMDs ( string md ) {
    #    list<list<map> > ret = [];
    #    foreach( string dev, map devmap, Storage::GetTargetMap(),
    #             ``{
    #        ret = add( ret,
    #                   filter( map part, devmap["partitions"]:[],
    #                           ``(
    #                              part["raid_name"]:"" == md
    #                              &&
    #                              part["delete"]:false
    #                              &&
    #                              part["fsid"]:0 == Partitions::fsid_raid
    #                              )
    #                           )
    #                   );
    #    });
    #
    #    return( flatten(ret) );
    #     }


    # Delete MDs
    # @return [Array] list of deleted MDs

    # useless
    #     global define list DeleteMDs () {
    #    list to_bo_deleted = [];
    #    foreach( string dev, map devmap, Storage::GetTargetMap(), ``{
    #        foreach( map part,  devmap["partitions"]:[], ``{
    #            if (part["old_raid_name"]:"" != "" && part["delete"]:false)
    #            {
    #                to_bo_deleted= add(to_bo_deleted, part["old_raid_name"]:"");
    #            }
    #        });
    #    });
    #
    #    y2milestone("mds to delete: %1", to_bo_deleted);
    #
    #    if (old_available)
    #    {
    #        list<map> mds = Storage::GetTargetMap()["/dev/md","partitions"]:[];
    #        list<map> new_mds = maplist( map md, mds ,``{
    #            if ( contains(to_bo_deleted, md["device"]:""))
    #            {
    #                md["delete"] = true;
    #            }
    #            return (md);
    #        });
    #        y2milestone("new_mds: %1", new_mds );
    #        map allmds =  targetMap["/dev/md"]:$[];
    #        allmds["partitions"] = new_mds;
    #        targetMap["/dev/md"] = allmds;
    #        Storage::SetTargetMap(targetMap);
    #    }
    #     }


    def remove_possible_mds
      prefer_remove = Ops.get_boolean(
        @raid,
        ["/dev/md", "prefer_remove"],
        false
      )
      if @old_available && prefer_remove
        existing_mds = Ops.get_list(
          @ExistingRAID,
          ["/dev/md", "partitions"],
          []
        )
        modified_mds = Builtins.maplist(existing_mds) do |md|
          Ops.set(md, "delete", true)
          deep_copy(md)
        end
        allmds = Convert.convert(
          Ops.get(@ExistingRAID, "/dev/md", {}),
          :from => "map",
          :to   => "map <string, any>"
        )
        Ops.set(allmds, "partitions", modified_mds)
        tg = Storage.GetTargetMap
        Ops.set(tg, "/dev/md", allmds)
        Storage.SetTargetMap(tg)
        # update our variable
        Ops.set(@ExistingRAID, "/dev/md", allmds)
      end
      true
    end

    # Create RAID Configuration
    # @return [Boolean]
    def Write
      remove_possible_mds
      raid_partitions = Ops.get_list(@raid, ["/dev/md", "partitions"], [])

      _RaidList = Builtins.maplist(raid_partitions) do |md|
        use = Ops.get_string(@raid, ["/dev/md", "use"], "none")
	dev = md.fetch("raid_options",{})["raid_name"]
	if !dev || dev.empty?
	  dev = "/dev/md"+md.fetch("partition_nr", 0).to_s
	end
        md["device"] = dev
        if md["crypt_fs"]
          Storage.SetCryptPwd(dev, Ops.get_string(md, "crypt_key", ""))
          md["enc_type"] = md["format"] ? :luks : :twofish
        end
        Builtins.y2milestone("Working on %1", md)
        chunk_size = 4
        options = Ops.get_map(md, "raid_options", {})
        raid_type = Ops.get_string(options, "raid_type", "raid1")
        chunk_size = 128 if raid_type == "raid5"
        chunk_size = 32 if raid_type == "raid0"
        if !Builtins.haskey(options, "raid_type")
          Ops.set(options, "raid_type", raid_type)
        end
        sel_chunksize = Builtins.tointeger(
          Ops.get_string(options, "chunk_size", "0")
        )
        if sel_chunksize != 0
          chunk_size = sel_chunksize
          Ops.set(options, "chunk_size", chunk_size)
        end
        if raid_type == "raid5" &&
            Ops.get_string(options, "parity_algorithm", "") == ""
          Ops.set(options, "parity_algorithm", "left_symmetric")
        end
        Ops.set(md, "nr", Ops.get_integer(md, "partition_nr", 0))
        if !Builtins.haskey(md, "create")
          Ops.set(md, "create", true)
          Ops.set(md, "status", "create")
        end
        Ops.set(md, "format", false) if !Builtins.haskey(md, "format")
        if Ops.get_boolean(md, "format", false)
          Ops.set(md, "used_fs", Ops.get_symbol(md, "filesystem", Partitions.DefaultFs))
        end
        md = AutoinstStorage.AddFilesysData(md, md)
        Ops.set(md, "type", :sw_raid)
        if Builtins.haskey(md, "raid_options")
          md = Builtins.remove(md, "raid_options")
        end
        Ops.set(
          md,
          "devices",
          Ops.get(
            AutoinstStorage.raid2device,
            Ops.get_string(md, "device", ""),
            []
          )
        )
        Builtins.union(md, options)
      end

      allraid = []
      if Ops.greater_than(
          Builtins.size(
            Ops.get_list(@ExistingRAID, ["/dev/md", "partitions"], [])
          ),
          0
        )
        allraid = Builtins.union(
          Ops.get_list(@ExistingRAID, ["/dev/md", "partitions"], []),
          _RaidList
        )
      else
        allraid = deep_copy(_RaidList)
      end
      Builtins.y2milestone("All RAID: %1", allraid)


      _RaidMap = { "partitions" => allraid, "type" => :CT_MD }
      Builtins.y2milestone("RaidMap: %1", _RaidMap)

      tg = Storage.GetTargetMap
      Ops.set(tg, "/dev/md", _RaidMap)
      Storage.SetTargetMap(tg)
      Builtins.y2milestone("Targets: %1", Storage.GetTargetMap)
      true
    end

    publish :variable => :ExistingRAID, :type => "map <string, map>"
    publish :variable => :old_available, :type => "boolean"
    publish :function => :AutoinstRAID, :type => "void ()"
    publish :function => :Init, :type => "boolean ()"
    publish :function => :ExistingMDs, :type => "list (string)"
    publish :function => :Write, :type => "boolean ()"
  end

  AutoinstRAID = AutoinstRAIDClass.new
  AutoinstRAID.main
end
