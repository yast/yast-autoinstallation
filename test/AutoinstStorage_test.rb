#!/usr/bin/env rspec

# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "test_helper"

Yast.import "AutoinstStorage"

describe "Yast::AutoinstStorage" do
  subject { Yast::AutoinstStorage }

  let(:partition1) { { "mount" => "/", "used_fs" => root_fs } }

  let(:partition2) { { "mount" => "/home", "used_fs" => :xfs } }

  let(:partition3) { { "mount" => "swap", "used_fs" => :swap } }

  let(:root_fs) { :btrfs }

  describe "#find_root_btrfs" do
    context "when there is no root partition" do
      let(:partitions) { [partition2, partition3] }

      it "returns nil" do
        expect(subject.find_root_btrfs(partitions)).to be_nil
      end
    end

    context "when there is a root partition" do
      let(:partitions) { [partition1, partition2, partition3] }

      context "but the filesystem is not Btrfs" do
        let(:root_fs) { :xfs }

        it "returns nil" do
          expect(subject.find_root_btrfs(partitions)).to be_nil
        end
      end

      context "and the filesystem is Btrfs" do
        let(:root_fs) { :btrfs }

        it "returns the root partition" do
          expect(subject.find_root_btrfs(partitions)).to eq(partition1)
        end
      end
    end
  end

  describe "#root_btrfs?" do
    context "when the partition is not mounted" do
      let(:partition) { { "mount" => nil } }

      it "returns false" do
        expect(subject.root_btrfs?(partition)).to eq(false)
      end
    end

    context "when the partition is not mounted at root" do
      let(:partition) { partition2 }

      it "returns false" do
        expect(subject.root_btrfs?(partition)).to eq(false)
      end
    end

    context "when the partition is mounted at root" do
      let(:partition) { partition1 }

      context "but the filesystem is not Btrfs" do
        let(:root_fs) { :xfs }

        it "returns false" do
          expect(subject.root_btrfs?(partition)).to eq(false)
        end
      end

      context "and the filesystem is Btrfs" do
        let(:root_fs) { :btrfs }

        it "returns true" do
          expect(subject.root_btrfs?(partition)).to eq(true)
        end
      end
    end
  end

  describe "#configure_root_btrfs" do
    let(:partition) { { "mount" => "/", "used_fs" => :btrfs, "subvol" => subvolumes } }

    let(:subvolumes) { nil }

    let(:device) { "/dev/sda" }

    let(:data) { {} }

    context "when the 'enable_snapshots' option is set" do
      let(:data) { { "enable_snapshots" => true } }

      it "configures the partition to enable snapshots" do
        subject.configure_root_btrfs(partition, device: device, data: data)

        expect(partition["userdata"]["/"]).to eq("snapshots")
      end
    end

    context "when the 'enable_snapshots' option is not set" do
      let(:data) { { "enable_snapshots" => false } }

      it "does not configure the partition to enable snapshots" do
        subject.configure_root_btrfs(partition, device: device, data: data)

        expect(partition["userdata"]).to be_nil
      end
    end

    context "when the partition contains subvolumes" do
      let(:subvolumes) { [:subvolume1, :subvolume2] }

      it "does not modify the list of subvolumes" do
        subject.configure_root_btrfs(partition, device: device, data: data)

        expect(partition["subvol"]).to eq(subvolumes)
      end
    end

    context "when the partition does not contain subvolumes" do
      let(:subvolumes) { nil }

      before do
        subject.instance_variable_set(:@AutoPartPlan, control_file)
      end

      let(:control_file) { [ { "device" => "/dev/sda", "partitions" => partitions } ] }

      context "and the control file does not contain a root Btrfs for the device" do
        let(:partitions) { [] }

        it "sets the list of subvolumes" do
          subject.configure_root_btrfs(partition, device: device, data: data)

          expect(partition["subvol"]).to_not be_empty
        end
      end

      context "and the control file contains a root Btrfs for the device" do
        let(:partitions) { [partition1, partition2] }

        it "does not set the list of subvolumes" do
          subject.configure_root_btrfs(partition, device: device, data: data)

          expect(partition["subvol"]).to be_nil
        end
      end
    end
  end
end
