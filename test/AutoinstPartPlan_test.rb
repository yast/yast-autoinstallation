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

  describe "#Read" do
    let(:probed) { instance_double(Y2Storage::Devicegraph) }

    let(:partitioning) do
      Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
        [{ "device" => "/dev/vda" }]
      )
    end

    before do
      allow(Y2Storage::StorageManager.instance).to receive(:probed).and_return(probed)
      allow(Y2Storage::AutoinstProfile::PartitioningSection).to receive(:new_from_storage)
        .with(probed)
        .and_return(partitioning)
      subject.Reset
    end

    it "stores the plan for the probed partitioning layout" do
      subject.Read
      expect(subject.Export).to eq(partitioning.to_hashes)
    end

    it "returns true" do
      expect(subject.Read).to eq(true)
    end
  end

  describe "#Import" do
    let(:partitioning) do
      Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
        [{ "device" => "/dev/vda" }]
      )
    end

    context "when an partitioning partitioning object is give" do
      it "stores the given object as the partitioning plan" do
        subject.Import(partitioning)
        expect(subject.Export).to eq(partitioning.to_hashes)
      end
    end

    context "when an array of hashes is given" do
      let(:profile) { [double("drive1")] }

      before do
        allow(Y2Storage::AutoinstProfile::PartitioningSection)
          .to receive(:new_from_hashes).with(profile).and_return(partitioning)
      end

      it "processes the array and stores the correspondant partitioning partitioning" do
        subject.Import(profile)
        expect(subject.Export).to eq(partitioning.to_hashes)
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

  describe "#Summary" do
    let(:partitioning) do
      Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
        [
          { "device" => "/dev/vda", "partitions" => [{ "mount" => "/" }] }
        ]
      )
    end

    it "exports the partitioning summary" do
      subject.Import(partitioning)
      summary = subject.Summary
      expect(summary).to include("Drive (Disk): /dev/vda")
      expect(summary).to include("Partition: /")
    end
  end
end
