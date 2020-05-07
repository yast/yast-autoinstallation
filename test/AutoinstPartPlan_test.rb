#!/usr/bin/env rspec

require_relative "test_helper"
require "yaml"
require "y2storage"

Yast.import "Profile"
Yast.import "ProductFeatures"

describe "Yast::AutoinstPartPlan" do
  before do
    fake_storage_scenario("autoyast_drive_examples.yml")

    allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
  end

  subject do
    # Postpone AutoinstPartPlan.main until it is needed.
    Yast.import "AutoinstPartPlan"
    Yast::AutoinstPartPlan
  end

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
    before :all do
      skip("pending on nfs definition in yml files")
    end

    it "exporting nfs root partition" do
      expect(subject.Read).to eq(true)
      expect(subject.Export).to eq(
        [{ "type" => :CT_NFS,
           "partitions" => [{ "type"   => :nfs,
                              "device" => "192.168.4.1:/srv/nfsroot/sles12sp1",
                              "mount"  => "/",
                              "fstopt" => "minorversion=1" }],
           "device" => "/dev/nfs", "use" => "all" }]
      )
    end
  end

  describe "#Import" do
    let(:sda) { { "device" => "/dev/sda", "initialize" => true } }
    let(:sdb) { { "device" => "/dev/sdb" } }
    let(:settings) { [sda, sdb] }

    before { subject.Import(settings) }

    context "\"initialize\" is not given" do
      it "set default value for \"initialize\" to false" do
        drive = subject.getDrive(1)
        expect(drive["initialize"]).to eq(false)
      end
    end

    context "\"initialize\" is given" do
      it "does not overwrite \"initialize\" with default setting" do
        drive = subject.getDrive(0)
        expect(drive["initialize"]).to eq(true)
      end
    end
  end

  describe "#Export" do

    let(:exported) { subject.Export }
    let(:sub_partitions) { exported.detect { |d| d["device"] == "/dev/sdd" }["partitions"] }
    let(:subvolumes) { sub_partitions.first["subvolumes"].sort_by { |s| s["path"] } }

    before do
      subject.Read
    end

    it "includes found subvolumes" do
      expect(subvolumes).to eq([
                                 { "path" => "home", "copy_on_write" => true },
                                 { "path" => "log", "copy_on_write" => true },
                                 { "path" => "opt", "copy_on_write" => true },
                                 { "path" => "srv", "copy_on_write" => true },
                                 { "path" => "tmp", "copy_on_write" => true },
                                 { "path" => "usr/local", "copy_on_write" => true },
                                 { "path" => "var/cache", "copy_on_write" => true },
                                 { "path" => "var/crash", "copy_on_write" => true },
                                 { "path" => "var/lib/mariadb", "copy_on_write" => false },
                                 { "path" => "var/lib/mysql", "copy_on_write" => false },
                                 { "path" => "var/lib/pgsql", "copy_on_write" => false }
                               ])
    end

    it "does not include snapshots" do
      snapshots = subvolumes.select { |s| s.include?("snapshot") }
      expect(snapshots).to be_empty
    end

    it "does not include drive indexes" do
      drives = subject.Export
      expect(drives.first.keys).to_not include("_id")
    end
  end

  describe "#getDrive" do
    let(:sda) { { "device" => "/dev/sda" } }
    let(:sdb) { { "device" => "/dev/sdb" } }
    let(:settings) { [sda, sdb] }

    before { subject.Import(settings) }

    it "returns the drive in the given position" do
      drive = subject.getDrive(1)
      expect(drive["device"]).to eq("/dev/sdb")
    end

    context "when the drive does not exist" do
      it "returns an empty hash" do
        expect(subject.getDrive(2)).to eq({})
      end
    end
  end

  describe "#getPartition" do
    let(:sda) do
      { "device" => "/dev/sda", "partitions" => [{ "mount" => "/" }, { "mount" => "/home" }] }
    end
    let(:settings) { [sda] }

    before { subject.Import(settings) }

    it "returns the drive in the given position" do
      expect(subject.getPartition(0, 1)).to eq("mount" => "/home")
    end

    context "when the drive does not exist" do
      it "returns an empty hash" do
        expect(subject.getPartition(1, 0)).to eq({})
      end
    end

    context "when the partition does not exist" do
      it "returns an empty hash" do
        expect(subject.getPartition(0, 2)).to eq({})
      end
    end
  end
end
