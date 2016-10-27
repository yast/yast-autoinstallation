#!/usr/bin/env rspec

require_relative "test_helper"
require "yaml"

Yast.import "AutoinstPartPlan"
Yast.import "Profile"
Yast.import "ProductFeatures"

describe Yast::AutoinstPartPlan do
  let(:target_map_path) { File.join(FIXTURES_PATH, "storage", "nfs_root.yml") }
  let(:target_map_clone) { File.join(FIXTURES_PATH, "storage", "target_clone.yml") }

  describe "#read partition target" do

    it "exporting nfs root partition" do
      target_map = YAML.load_file(target_map_path)

      expect(Yast::Storage).to receive(:GetTargetMap).and_return(target_map)
      expect(Yast::AutoinstPartPlan.Read).to eq(true)
      expect(Yast::AutoinstPartPlan.Export).to eq(
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
      expect(Yast::AutoinstPartPlan.Read).to eq(true)
      export = Yast::AutoinstPartPlan.Export.select { |d| d.key?("skip_list") }
      expect(export).to eq(
        [ { "initialize"=>true,
            "skip_list"=>
              [{"skip_key"=>"device", "skip_value"=>"/dev/sdb"},
               {"skip_key"=>"device", "skip_value"=>"/dev/sde"}]
          }
        ]
      )
    end
  end

  describe "#Export" do
    let(:target_map) { YAML.load_file(File.join(FIXTURES_PATH, "storage", "subvolumes.yml")) }
    let(:default_subvol) { "@" }

    before do
      allow(Yast::Storage).to receive(:GetTargetMap).and_return(target_map)
      stub_const("Yast::FileSystems", double("filesystems", default_subvol: default_subvol))
      Yast::AutoinstPartPlan.Read
    end

    it "includes found subvolumes" do
      exported = Yast::AutoinstPartPlan.Export
      subvolumes = exported.first["partitions"].first["subvolumes"]
      expect(subvolumes).to eq([
        { "path" => "@" },
        { "path" => "home" },
        { "path" => "var/log" },
        { "path" => "var/lib/pgsql" },
        { "path" => "myvol", "copy_on_write" => false },
      ])
    end

    it "does not include snapshots" do
      exported = Yast::AutoinstPartPlan.Export
      subvolumes = exported.first["partitions"].first["subvolumes"]
      snapshots = subvolumes.select { |s| s.include?("snapshot") }
      expect(snapshots).to be_empty
    end
  end

  describe "#find_btrfs_subvol_name_default" do
    let(:target_map) { YAML.load_file(File.join(FIXTURES_PATH, "storage", "subvolumes.yml")) }
    let(:btrfs_list) { File.read(File.join(FIXTURES_PATH, "output", "btrfs_list.out")) }
    let(:btrfs_list_no_at) { File.read(File.join(FIXTURES_PATH, "output", "btrfs_list_no_at.out")) }
    let(:default_subvol) { "@" }

    before do
      allow(Yast::Storage).to receive(:GetTargetMap).and_return(target_map)
      allow(Yast::ProductFeatures).to receive(:GetStringFeature)
        .with("partitioning", "btrfs_default_subvolume").and_return(default_subvol)
    end

    context "when root partition uses the default subvolume name (@)" do
      let(:btrfs_list) { File.read(File.join(FIXTURES_PATH, "output", "btrfs_list.out")) }

      it "returns the default subvolume name" do
        allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/", anything)
          .and_return(btrfs_list)
        allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/srv", anything)
          .and_return(btrfs_list_no_at)
        expect(subject.find_btrfs_subvol_name_default).to eq(default_subvol)
      end
    end

    context "when root partitions does not use the default subvolume name (@)" do
      before do
        allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/", anything)
          .and_return(btrfs_list_no_at)
      end

      context "but all partitions uses the same subvolume name" do
        before do
          allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/srv", anything)
            .and_return(btrfs_list_no_at)
        end

        it "returns the used name ('' in this case)" do
          expect(Yast::AutoinstPartPlan.find_btrfs_subvol_name_default).to eq("")
        end
      end

      context "and partitions uses different subvolume names" do
        before do
          allow(Yast::Execute).to receive(:on_target).with("btrfs", "subvol", "list", "/srv", anything)
            .and_return(btrfs_list)
        end

        it "returns the distribution default" do
          value = Yast::AutoinstPartPlan.find_btrfs_subvol_name_default
          expect(value).to eq("")
        end
      end
    end
  end
end
