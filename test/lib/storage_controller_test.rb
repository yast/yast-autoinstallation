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
require "autoinstall/presenters"
require "y2storage/autoinst_profile/partitioning_section"
require "y2storage/autoinst_profile/partition_section"

describe Y2Autoinstallation::StorageController do
  subject { described_class.new(partitioning) }

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes([])
  end

  describe "#add_drive" do
    it "adds a new section with the given type" do
      subject.add_drive(Y2Autoinstallation::Presenters::DriveType::DISK)
      new_drive = partitioning.drives.first
      expect(new_drive.type).to eq(:CT_DISK)
    end
  end

  describe "#add_partition" do
    let(:partitioning) do
      Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
        [{ "type" => :CT_DISK }]
      )
    end

    it "adds a new partition section" do
      subject.add_partition
      drive = partitioning.drives.first
      expect(drive.partitions).to contain_exactly(
        an_instance_of(Y2Storage::AutoinstProfile::PartitionSection)
      )
    end
  end

  describe "#delete_section" do
    let(:partitioning) do
      Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
        [
          { "type" => :CT_DISK, "partitions" => [{ "create" => true }] },
          { "type" => :CT_DISK, "partitions" => [{ "create" => false, "size" => "1 TiB" }] },
          { "type" => :CT_RAID, "partitions" => [{ "create" => true }, { "create" => false }] },
          { "type" => :CT_DISK, "partitions" => [{ "create" => true }] }
        ]
      )
    end

    let(:drive) { partitioning.drives[2] }
    let(:first_partition) { drive.partitions.first }

    context "when deleting a partition section" do
      it "removes selected section" do
        subject.section = first_partition
        subject.delete_section

        expect(drive.partitions).to_not include(first_partition)
      end

      it "sets its parent drive section as selected" do
        subject.section = first_partition
        subject.delete_section

        expect(subject.section).to eq(drive)
      end
    end

    context "when deleting a drive section" do
      it "removes selected section" do
        subject.section = drive
        subject.delete_section

        expect(subject.drives).to_not include(drive)
      end

      it "sets the first drive section as selected" do
        subject.section = drive
        subject.delete_section

        expect(subject.section).to eq(subject.drives.first)
      end
    end
  end
end
