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
require "autoinstall/storage_controller"
require "y2storage/autoinst_profile"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::PartitionPage do
  subject { described_class.new(controller, drive, partition) }

  include_examples "CWM::Page"

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
      [{ "type" => type, "partitions" => [partition_hash] }]
    )
  end
  let(:type) { :CT_DISK }
  let(:drive) { partitioning.drives.first }
  let(:partition) { drive.partitions.first }
  let(:controller) { Y2Autoinstallation::StorageController.new(partitioning) }
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
          expect(subject.label).to eq("Partition")
        end
      end
    end

    context "when the partition will be used as RAID member" do
      let(:partition_hash) { { "raid_name" => "/dev/md0" } }

      it "returns a description" do
        expect(subject.label).to eq("Part of /dev/md0")
      end
    end

    context "when the partition will be used as LVM PV" do
      let(:partition_hash) { { "lvm_group" => "/dev/system" } }

      it "returns a description" do
        expect(subject.label).to eq("Partition for PV /dev/system")
      end
    end
  end

  describe "#contents" do
    context "when the partition belongs to an LVM" do
      let(:type) { :CT_LVM }

      it "includes LVM partition attributes" do
        widget = subject.contents.nested_find do |w|
          w.is_a?(Y2Autoinstallation::Widgets::Storage::LvmPartitionAttrs)
        end

        expect(widget).to_not be_nil
      end
    end
  end

  describe "#store" do
    let(:used_as_widget) do
      instance_double(Y2Autoinstallation::Widgets::Storage::UsedAs, value: "filesystem")
    end

    before do
      allow(Y2Autoinstallation::Widgets::Storage::UsedAs).to receive(:new)
        .and_return(used_as_widget)
    end

    it "sets the partition section attributes" do
      expect(controller).to receive(:update_partition).with(partition, anything)
      subject.store
    end
  end
end
