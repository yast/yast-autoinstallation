#!/usr/bin/env rspec
require_relative "../test_helper"
require "yaml"

# storage-ng
=begin
Yast.import "Profile"
Yast.import "Arch"
Yast.import "Partitions"
=end

describe "Yast::AutoinstallAutopartInclude" do
  # storage-ng
  before :all do
    skip("pending of storage-ng")
  end
  
  module DummyYast
    class AutoinstallAutopartClient < Yast::Client
      include Yast::Logger

      def main
        Yast.include self, "autoinstall/autopart.rb"
        @planHasBoot=false
      end

      def initialize
        main
      end
      def plan_has_boot_or_prep_partition
        @planHasBoot
      end
      def plan_has_boot_or_prep_partition=(v)
        @planHasBoot = v
      end
    end
  end

  subject(:client) { DummyYast::AutoinstallAutopartClient.new }

  describe "#autopart" do

    context "ppc partitioning" do
      let(:target_map) { YAML.load_file(File.join(FIXTURES_PATH, 'storage', 'target_ppc.yml')) }
      let(:ay_device) { Yast::Profile.current['partitioning'].find {|x| x["device"] == checked_device} }
      before do
        allow(Yast::Arch).to receive(:ppc).and_return(true)
        allow(Yast::Partitions).to receive(:MinimalNeededBootsize).and_return(800000)
        allow(Yast::Partitions).to receive(:DefaultBootFs).and_return(:ext4)
        allow(Yast::Partitions).to receive(:FsidBoot).and_return(Yast::Partitions.fsid_gpt_prep)
        Yast::Profile.ReadXML(File.join(FIXTURES_PATH, 'profiles', 'ppc_partitions.xml'))
      end

      context "AY configuration file has no prep partition" do
        before do
          client.plan_has_boot_or_prep_partition=false
        end

        context "checking device with root partition" do
          let(:checked_device) { "/dev/sdc" }

          it "do not add an additional prep partition if it is a powernv system" do
            # bnc#989392
            allow(Yast::Arch).to receive(:board_powernv).and_return(true)
            ret = client.try_add_boot( ay_device, target_map[checked_device])
            expect(ret["partitions"].size).to eq(ay_device["partitions"].size)
          end

          it "adds an additional prep partition if it is NOT a powernv system" do
            allow(Yast::Arch).to receive(:board_powernv).and_return(false)
            ret = client.try_add_boot( ay_device, target_map[checked_device])
            expect(ret["partitions"].size).to eq(ay_device["partitions"].size + 1)
            # added disk has no mount point
            expect((ret["partitions"] - ay_device["partitions"]).first.key?("mount")).to eq(false)
            # added disk has no fsys
            expect((ret["partitions"] - ay_device["partitions"]).first.key?("fsys")).to eq(false)
          end
        end

        context "checking device without root partition" do
          let(:checked_device) { "/dev/sdb" }

          it "do not add an additional prep partition for ppc" do
            allow(Yast::Arch).to receive(:board_powernv).and_return(false)
            ret = client.try_add_boot( ay_device, target_map[checked_device])
            expect(ret["partitions"].size).to eq(ay_device["partitions"].size)
          end
        end
      end

      context "AY configuration file has a prep partition" do
        before do
          client.plan_has_boot_or_prep_partition=true
        end

        context "checking device with root partition" do
          let(:checked_device) { "/dev/sdc" }

          it "do not add an additional prep partition if it is NOT a powernv system" do
            allow(Yast::Arch).to receive(:board_powernv).and_return(false)
            ret = client.try_add_boot( ay_device, target_map[checked_device])
            expect(ret["partitions"].size).to eq(ay_device["partitions"].size)
          end
        end

        context "checking device without root partition" do
          let(:checked_device) { "/dev/sdb" }

          it "do not add an additional prep partition for ppc" do
            allow(Yast::Arch).to receive(:board_powernv).and_return(false)
            ret = client.try_add_boot( ay_device, target_map[checked_device])
            expect(ret["partitions"].size).to eq(ay_device["partitions"].size)
          end
        end
      end
    end

    describe "#AddSubvolData" do
      before do
        subject.main
        stub_const("Yast::FileSystems", double("filesystems", default_subvol: default_subvol))
      end

      let(:default_subvol) { "" }

      let(:target) do
        {
          "create" => true, "device" => "/dev/sda2", "format" => true, "fstopt" => "subvol=@",
          "mount" => "/", "mountby" => :uuid, "nr" => 2, "region" => [94, 1733], "type" => :primary,
          "used_fs" => :btrfs
        }
      end

      context "when subvolumes specification are just paths" do
        it "adds subvolumes with default options" do
          new_target = client.AddSubvolData(target, "subvolumes" => ["home", "var/lib/pgsql"])
          expect(new_target["subvol"]).to eq([
              {"name" => "home", "create" => true },
              {"name" => "var/lib/pgsql", "create" => true}
            ])
        end
      end

      context "when a default subvolme is specified" do
        let(:default_subvol) { "@" }

        it "prepends the default subvolume" do
          new_target = client.AddSubvolData(target, "subvolumes" => ["home"])
          expect(new_target["subvol"]).to eq([{"name" => "@/home", "create" => true}])
        end
      end

      context "when copy-on-write is defined" do
        let(:subvolumes) do
          [ { "path" => "home" }, { "path" => "var/lib/pgsql", "copy_on_write" => false } ]
        end

        it "includes the 'nocow' option" do
          new_target = client.AddSubvolData(target, "subvolumes" => subvolumes)
          expect(new_target["subvol"]).to eq([
              { "name" => "home", "create" => true },
              { "name" => "var/lib/pgsql", "create" => true, "nocow" => true }
            ])
        end
      end

      context "when path is not defined" do
        let(:subvolumes) do
          [ { "name" => "home" } ]
        end

        it "does not add the subvolume" do
          new_target = client.AddSubvolData(target, "subvolumes" => subvolumes)
          expect(new_target["subvol"]).to be_empty
        end
      end
    end
  end
end
