#!/usr/bin/env rspec

require_relative "../test_helper"
require "yaml"
require "yast"

Yast.import "Profile"
Yast.import "Arch"
Yast.import "Partitions"

describe "Yast::AutoinstallAutopartInclude" do
  FIXTURES_PATH = File.join(File.dirname(__FILE__), '../fixtures')

  module DummyYast
    class AutoinstallAutopartClient < Yast::Client
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

          it "do not add an additional prep partition if it is NOT a powerpc system" do
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
  end
end
