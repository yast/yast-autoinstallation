#!/usr/bin/env rspec

require_relative "test_helper"
require "yaml"

Yast.import "Profile"
Yast.import "ProductFeatures"
Yast.import "Storage"

describe "Yast::AutoinstPartPlan" do
  subject do
    # Postpone AutoinstPartPlan.main until it is needed.
    Yast.import "AutoinstPartPlan"
    Yast::AutoinstPartPlan
  end

  let(:target_map_path) { File.join(FIXTURES_PATH, "storage", "nfs_root.yml") }
  let(:target_map_clone) { File.join(FIXTURES_PATH, "storage", "target_clone.yml") }
  let(:default_subvol) { "@" }
  let(:filesystems) do
    double("filesystems",
      default_subvol: default_subvol, read_default_subvol_from_target: default_subvol,
      GetAllFileSystems: {})
  end

  before do
    allow(Yast).to receive(:import).with("FileSystems").and_return(nil)
    allow(Yast).to receive(:import).and_call_original
    stub_const("Yast::FileSystems", filesystems)
  end

  describe "#read partition target" do

    it "exporting nfs root partition" do
      target_map = YAML.load_file(target_map_path)

      expect(Yast::Storage).to receive(:GetTargetMap).and_return(target_map)
      expect(subject.Read).to eq(true)
      expect(subject.Export).to eq(
         [{"type"=>:CT_NFS,
            "partitions"=>[{"type"=>:nfs,
              "device"=>"192.168.4.1:/srv/nfsroot/sles12sp1",
              "mount"=>"/",
              "fstopt"=>"minorversion=1"}],
            "device"=>"/dev/nfs", "use"=>"all"}
         ]
        )
    end

    it "ignoring not needed devices" do
      target_map = YAML.load_file(target_map_clone)

      expect(Yast::Storage).to receive(:GetTargetMap).and_return(target_map)
      expect(subject.Read).to eq(true)
      export = subject.Export.select { |d| d.key?("skip_list") }

      expect(export[0]).to include("initialize" => true)
      skip_list = export[0]["skip_list"]
      expect(skip_list).to all(include("skip_key" => "device"))
      expect(skip_list).to all(include("skip_value" => /\/dev\//))
    end
  end

  describe "#Export" do
    let(:target_map) { YAML.load_file(File.join(FIXTURES_PATH, "storage", "subvolumes.yml")) }

    before do
      allow(Yast::Storage).to receive(:GetTargetMap).and_return(target_map)
      subject.Read
    end

    it "includes found subvolumes" do
      exported = subject.Export
      subvolumes = exported.first["partitions"].first["subvolumes"]
      expect(subvolumes).to eq([
        { "path" => "@", "copy_on_write" => true},
        { "path" => "home", "copy_on_write" => true },
        { "path" => "var/log", "copy_on_write" => true },
        { "path" => "var/lib/pgsql", "copy_on_write" => true },
        { "path" => "myvol", "copy_on_write" => false },
      ])
    end

    it "does not include snapshots" do
      exported = subject.Export
      subvolumes = exported.first["partitions"].first["subvolumes"]
      snapshots = subvolumes.select { |s| s.include?("snapshot") }
      expect(snapshots).to be_empty
    end

    context "when the drive has a msdos partition" do
      it "includes the partition_type" do
        exported = subject.Export
        partition = exported.first["partitions"].first
        expect(partition).to include("partition_type" => "primary")
      end
    end

    context "when the drive has a non-msdos partition" do
      let(:target_map) { YAML.load_file(File.join(FIXTURES_PATH, "storage", "target_clone.yml")) }

      it "does not include the partition_type" do
        exported = subject.Export
        partition = exported.first["partitions"].first
        expect(partition).to_not have_key("partition_type")
      end
    end
  end
end
