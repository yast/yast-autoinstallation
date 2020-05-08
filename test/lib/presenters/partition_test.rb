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

require_relative "../../test_helper"
require "autoinstall/presenters"
require "y2storage/autoinst_profile/partitioning_section"
require "y2storage/autoinst_profile/partition_section"

describe Y2Autoinstallation::Presenters::Partition do
  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(part_hashes)
  end

  let(:part_hashes) do
    [{ "type" => :CT_DISK }]
  end

  let(:section) { Y2Storage::AutoinstProfile::PartitionSection.new }

  let(:drive_section) do
    sect = partitioning.drives.first
    sect.partitions << section
    sect
  end

  let(:drive) { Y2Autoinstallation::Presenters::Drive.new(drive_section) }

  subject { drive.partitions.first }

  describe "#update" do
    context "when file system attributes are given" do
      let(:values) do
        { filesystem: :ext4, mount: "/home" }
      end

      it "sets the file system attributes" do
        subject.update(values)
        expect(subject.section.filesystem).to eq(:ext4)
        expect(subject.section.mount).to eq("/home")
      end

      it "clears non filesystem specific attributes" do
        subject.update(values)
        expect(subject.section.raid_name).to be_nil
      end
    end

    context "when RAID attributes are given" do
      let(:values) do
        { raid_name: "/dev/md1" }
      end

      it "sets the RAID attributes" do
        subject.update(values)
        expect(section.raid_name).to eq("/dev/md1")
      end

      it "clears non RAID specific attributes" do
        subject.update(values)
        expect(section.filesystem).to be_nil
        expect(section.mount).to be_nil
      end
    end
  end

  describe "#usage" do
    let(:section) do
      Y2Storage::AutoinstProfile::PartitionSection.new_from_hashes(attrs)
    end

    context "when the section refers to a file system" do
      let(:attrs) { { filesystem: :ext4 } }

      it "returns :filesystem" do
        expect(subject.usage).to eq(:filesystem)
      end
    end

    context "when the section refers to a RAID member" do
      let(:attrs) { { raid_name: "/dev/md0" } }

      it "returns :raid" do
        expect(subject.usage).to eq(:raid)
      end
    end

    context "when the section refers to an LVM PV" do
      let(:attrs) { { lvm_group: "system" } }

      it "returns :lvm_pv" do
        expect(subject.usage).to eq(:lvm_pv)
      end
    end
  end

  describe "#available_lvm_groups" do
    context "when there are no LVM drive sections" do
      it "returns an empty collection" do
        expect(subject.available_lvm_groups).to eq([])
      end
    end

    context "when there are LVM drive section" do
      let(:part_hashes) do
        [
          { "type" => :CT_DISK },
          { "type" => :CT_LVM, "device" => "/dev/vg-0" },
          { "type" => :CT_LVM, "device" => "/dev/vg-1" }
        ]
      end

      it "returns a collection of LVM drive sections device" do
        expect(subject.available_lvm_groups).to eq(["vg-0", "vg-1"])
      end
    end
  end
end
