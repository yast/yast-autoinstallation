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
    it "clears and sets given attributes" do
      expect(section).to receive(:size=).with(nil)
      expect(section).to receive(:size=).with(:whatever)

      subject.update("size" => :whatever)
    end

    it "does not clear omitted attributes" do
      expect(section).to_not receive(:size=)

      subject.update("filesystem" => :btrfs)
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

    context "when the section does not refer an specific usage" do
      let(:attrs) { {} }

      it "returns :none" do
        expect(subject.usage).to eq(:none)
      end

      context "and it has an empty mount point" do
        let(:attrs) { { mount: "" } }

        it "returns :none" do
          expect(subject.usage).to eq(:none)
        end
      end

      context "but it has a not empty mount point" do
        let(:attrs) { { mount: "/home" } }

        it "returns :filesystem" do
          expect(subject.usage).to eq(:filesystem)
        end
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

  describe "#available_bcaches" do
    context "when there are no bcache drive sections" do
      it "returns an empty collection" do
        expect(subject.available_bcaches).to eq([])
      end
    end

    context "when there are bcache drive sections" do
      let(:part_hashes) do
        [
          { "type" => :CT_DISK },
          { "type" => :CT_LVM, "device" => "/dev/vg-0" },
          { "type" => :CT_BCACHE, "device" => "/dev/bcache0" },
          { "type" => :CT_BCACHE, "device" => "/dev/bcache1" }
        ]
      end

      it "returns a collection of bcache drive sections device" do
        expect(subject.available_bcaches).to eq(["/dev/bcache0", "/dev/bcache1"])
      end
    end
  end
end
