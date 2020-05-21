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
require "autoinstall/widgets/storage/overview_tree_pager"
require "autoinstall/storage_controller"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::OverviewTreePager do
  subject { described_class.new(controller) }

  include_examples "CWM::Pager"

  let(:partitioning) { Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(attrs) }
  let(:attrs) do
    [
      { "device" => "/dev/sda", "partitions" => [{ "mount" => "/" }] },
      { "type" => :CT_RAID },
      { "type" => :CT_LVM },
      { "type" => :CT_BCACHE }
    ]
  end

  let(:controller) { Y2Autoinstallation::StorageController.new(partitioning) }

  describe "#items" do
    it "returns one item for each drive" do
      expect(subject.items.map(&:page)).to contain_exactly(
        an_instance_of(Y2Autoinstallation::Widgets::Storage::DiskPage),
        an_instance_of(Y2Autoinstallation::Widgets::Storage::RaidPage),
        an_instance_of(Y2Autoinstallation::Widgets::Storage::LvmPage),
        an_instance_of(Y2Autoinstallation::Widgets::Storage::BcachePage)
      )
    end

    context "when the type is unknown" do
      let(:attrs) do
        [{ "type" => :CT_UNKNOWN }]
      end

      it "considers that the section corresponds to a disk" do
        expect(subject.items.map(&:page)).to contain_exactly(
          an_instance_of(Y2Autoinstallation::Widgets::Storage::DiskPage)
        )
      end
    end
  end

  describe "#handle" do
    let(:delete_button) do
      instance_double(Y2Autoinstallation::Widgets::Storage::DeleteSectionButton)
    end

    let(:event) { { "ID" => :whatever } }
    let(:drive) { partitioning.drives.first }

    before do
      allow(Y2Autoinstallation::Widgets::Storage::DeleteSectionButton).to receive(:new)
        .and_return(delete_button)
    end

    context "when there are more than one drive section" do
      it "enables the deletion button" do
        expect(delete_button).to receive(:enable)

        subject.handle(event)
      end
    end

    context "when there is only one drive" do
      let(:attrs) do
        [
          { "type" => :CT_DISK, "device" => "/dev/sda", "partitions" => [{ "mount" => "/" }] }
        ]
      end

      context "and it is selected" do
        before do
          controller.section = drive
        end

        it "disables the deletion button" do
          expect(delete_button).to receive(:disable)

          subject.handle(event)
        end
      end

      context "but a partition is selected" do
        before do
          controller.section = drive.partitions.first
        end

        it "enables the deletion button" do
          expect(delete_button).to receive(:enable)

          subject.handle(event)
        end
      end
    end
  end
end
