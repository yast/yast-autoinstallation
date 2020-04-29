# Copyright (c) [2020] SUSE LLC
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

require_relative "../test_helper"
require "autoinstall/storage_controller"
require "y2storage/autoinst_profile/partitioning_section"
require "y2storage/autoinst_profile/partition_section"

describe Y2Autoinstallation::StorageController do
  subject { described_class.new(partitioning) }

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes([])
  end

  describe "#add" do
    it "adds a new section with the given type" do
      subject.add_drive(:disk)
      new_drive = partitioning.drives.first
      expect(new_drive.type).to eq(:CT_DISK)
    end
  end

  describe "#update_partition" do
    let(:section) do
      Y2Storage::AutoinstProfile::PartitionSection.new_from_hashes(
        filesystem: :btrfs,
        mount:      "/",
        raid_name:  "/dev/md0"
      )
    end

    context "when file system attributes are given" do
      let(:values) do
        { filesystem: :ext4, mount: "/home" }
      end

      it "sets the file system attributes" do
        subject.update_partition(section, values)
        expect(section.filesystem).to eq(:ext4)
        expect(section.mount).to eq("/home")
      end

      it "clears non filesystem specific attributes" do
        subject.update_partition(section, values)
        expect(section.raid_name).to be_nil
      end
    end

    context "when RAID attributes are given" do
      let(:values) do
        { raid_name: "/dev/md1" }
      end

      it "sets the RAID attributes" do
        subject.update_partition(section, values)
        expect(section.raid_name).to eq("/dev/md1")
      end

      it "clears non RAID specific attributes" do
        subject.update_partition(section, values)
        expect(section.filesystem).to be_nil
        expect(section.mount).to be_nil
      end
    end
  end

  describe "#partition_usage" do
    let(:section) do
      Y2Storage::AutoinstProfile::PartitionSection.new_from_hashes(attrs)
    end

    context "when the section refers to a file system" do
      let(:attrs) { { filesystem: :ext4 } }

      it "returns :filesystem" do
        expect(subject.partition_usage(section)).to eq(:filesystem)
      end
    end

    context "when the section refers to a RAID member" do
      let(:attrs) { { raid_name: "/dev/md0" } }

      it "returns :raid" do
        expect(subject.partition_usage(section)).to eq(:raid)
      end
    end

    context "when the section refers to an LVM PV" do
      let(:attrs) { { lvm_group: "system" } }

      it "returns :lvm_pv" do
        expect(subject.partition_usage(section)).to eq(:lvm_pv)
      end
    end
  end

  describe "#lvm_devices" do
    before do
      subject.add_drive(:CT_DISK)

      drive = subject.partitioning.drives.first
      subject.add_partition(drive)

      partition = drive.partitions.first
      subject.update_partition(partition, attrs)
    end

    context "when there are no LVM PV sections" do
      let(:attrs) { { raid_name: "/dev/md0" } }

      it "returns an empty collection" do
        expect(subject.lvm_devices).to eq([])
      end
    end

    context "when there are LVM PV sections" do
      let(:attrs) { { lvm_group: "system" } }

      it "returns a collection of LVM devices" do
        expect(subject.lvm_devices).to eq(["/dev/system"])
      end
    end
  end
end
