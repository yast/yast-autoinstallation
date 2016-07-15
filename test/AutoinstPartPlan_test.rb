#!/usr/bin/env rspec

require_relative "test_helper"
require "yaml"

Yast.import "AutoinstPartPlan"
Yast.import "Profile"

describe Yast::AutoinstPartPlan do
  FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures')
  let(:target_map_path) { File.join(FIXTURES_PATH, 'storage', "nfs_root.yml") }

  describe "#read partition target" do

    it "exporting nfs root partition" do
      target_map = YAML.load_file(target_map_path)

      expect(Yast::Storage).to receive(:GetTargetMap).and_return(target_map)
      expect(Yast::AutoinstPartPlan.Read).to eq(true)
      expect(Yast::AutoinstPartPlan.Export).to eq(
         [{"type"=>:CT_NFS, "disklabel"=>"msdos", 
            "partitions"=>[{"type"=>:nfs,
              "device"=>"192.168.4.1:/srv/nfsroot/sles12sp1",
              "mount"=>"/",
              "fstopt"=>"minorversion=1"}],
            "device"=>"/dev/nfs", "use"=>"all"}
         ]
        )
    end

  end

end
