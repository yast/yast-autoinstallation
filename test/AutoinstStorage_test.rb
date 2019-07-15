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
        puts "aaa"
        expect(subject.find_root_btrfs(partitions)).to be_nil
      end
    end
  end

  describe "#parsePartition" do
    let(:filesystem) { :btrfs }
    let(:subvolumes) do
      [
        { "path" => ".snapshots/1" },
        { "path" => "var/lib/machines" }
      ]
    end

    let(:partition) do
      { "filesystem" => filesystem, "subvolumes" => subvolumes }
    end

    it "filters out snapper snapshots" do
      parsed = subject.parsePartition(partition)
      expect(parsed["subvolumes"]).to eq(
        [{ "path" => "var/lib/machines" }]
      )
    end

    context "when there are no Btrfs subvolumes" do
      let(:subvolumes) { [] }

      it "exports them as an empty array" do
        parsed = subject.parsePartition(partition)
        expect(parsed["subvolumes"]).to eq([])
      end

      context "and filesystem is not Btrfs" do
        let(:filesystem) { :ext4 }

        it "does not export the subvolumes list" do
          parsed = subject.parsePartition(partition)
          expect(parsed).to_not have_key("subvolumes")
        end
      end
    end

    context "when a partition_type is present" do
      let(:partition) do
        { "mount" => "/", "partition_type" => "primary" }
      end

      it "exports the partition type" do
        parsed = subject.parsePartition(partition)
        expect(parsed["partition_type"]).to eq("primary")
      end
    end

    context "when a partition_type is not present" do
      let(:partition) do
        { "mount" => "/" }
      end

      it "ignores the partition_type" do
        parsed = subject.parsePartition(partition)
        expect(parsed).to_not have_key("partition_type")
      end
    end
  end
end
