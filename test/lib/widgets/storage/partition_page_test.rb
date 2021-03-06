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

require_relative "../../../test_helper"
require "autoinstall/widgets/storage/partition_page"
require "autoinstall/presenters"
require "y2storage/autoinst_profile"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::PartitionPage do
  subject { described_class.new(partition) }

  include_examples "CWM::Page"

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
      [{ "type" => type, "partitions" => [partition_hash] }]
    )
  end
  let(:type) { :CT_DISK }
  let(:drive) { Y2Autoinstallation::Presenters::Drive.new(partitioning.drives.first) }
  let(:partition) { drive.partitions.first }
  let(:partition_hash) { {} }

  describe "#label" do
    context "when the partition is used as a filesystem" do
      context "when the partition mount point is defined" do
        let(:partition_hash) { { "mount" => "/opt" } }

        it "includes the mount point" do
          expect(subject.label).to include("/opt")
        end
      end

      context "when the filesystem point is not defined" do
        let(:partition_hash) { { "filesystem" => :ext4 } }

        it "does not include the mount point" do
          expect(subject.label).to eq("Partition: Not Mounted")
        end
      end
    end

    context "when the partition will be used as RAID member" do
      let(:partition_hash) { { "raid_name" => "/dev/md0" } }

      it "returns a description" do
        expect(subject.label).to eq("Partition: Part of /dev/md0")
      end
    end

    context "when the partition will be used as LVM PV" do
      let(:partition_hash) { { "lvm_group" => "/dev/system" } }

      it "returns a description" do
        expect(subject.label).to eq("Partition: Part of /dev/system")
      end
    end
  end

  describe "#contents" do
    it "shows a tab for common options" do
      expect(Y2Autoinstallation::Widgets::Storage::PartitionGeneralTab).to receive(:new)
      subject.contents
    end

    it "shows a tab for options related to partition usage" do
      expect(Y2Autoinstallation::Widgets::Storage::PartitionUsageTab).to receive(:new)
      subject.contents
    end
  end
end
