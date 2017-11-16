#!/usr/bin/env rspec

require_relative "test_helper"
require "yaml"
require "y2storage"

Yast.import "Profile"
Yast.import "ProductFeatures"

def devicegraph_from(file_name)
  storage = Y2Storage::StorageManager.instance.storage
  st_graph = Storage::Devicegraph.new(storage)
  graph = Y2Storage::Devicegraph.new(st_graph)
  yaml_file = File.join(FIXTURES_PATH, "storage", file_name)
  Y2Storage::FakeDeviceFactory.load_yaml_file(graph, yaml_file)
  graph
end

describe "Yast::AutoinstPartPlan" do

  subject do
    # Postpone AutoinstPartPlan.main until it is needed.
    Yast.import "AutoinstPartPlan"
    Yast::AutoinstPartPlan
  end

  let(:devicegraph)  {devicegraph_from("autoyast_drive_examples.yml")}
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
    allow(Y2Storage::StorageManager.instance).to receive(:probed)
      .and_return(devicegraph)
  end

  describe "#read partition target" do
    before :all do
      skip("pending on nfs definition in yml files")
    end

    it "exporting nfs root partition" do
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
  end

  describe "#Export" do

    let(:exported) { subject.Export }
    let(:sub_partitions) { exported.detect {|d| d["device"] == "/dev/sdd"}["partitions"] }
    let(:subvolumes) { sub_partitions.first["subvolumes"].sort_by { |s| s["path"] } }

    before do
      subject.Read
    end

    it "includes found subvolumes" do
      expect(subvolumes).to eq([
        {"path"=>"home", "copy_on_write"=>true},
        {"path"=>"log", "copy_on_write"=>true},
        {"path"=>"opt", "copy_on_write"=>true},
        {"path"=>"srv", "copy_on_write"=>true},
        {"path"=>"tmp", "copy_on_write"=>true},
        {"path"=>"usr/local", "copy_on_write"=>true},
        {"path"=>"var/cache", "copy_on_write"=>true},
        {"path"=>"var/crash", "copy_on_write"=>true},
        {"path"=>"var/lib/mariadb", "copy_on_write"=>false},
        {"path"=>"var/lib/mysql", "copy_on_write"=>false},
        {"path"=>"var/lib/pgsql", "copy_on_write"=>false}
      ])
    end

    it "does not include snapshots" do
      snapshots = subvolumes.select { |s| s.include?("snapshot") }
      expect(snapshots).to be_empty
    end
  end
end
