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
require "autoinstall/widgets/storage/disk_page"
require "autoinstall/storage_controller"
require "y2storage/autoinst_profile"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::DiskPage do
  subject { described_class.new(controller, drive) }

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
      [{ "type" => :CT_DISK }]
    )
  end
  let(:drive) { partitioning.drives.first }
  let(:controller) { Y2Autoinstallation::StorageController.new(partitioning) }

  let(:disk_device_widget) do
    instance_double(
      Y2Autoinstallation::Widgets::Storage::DiskDevice,
      value: "/dev/sdb"
    )
  end

  let(:init_drive_widget) do
    instance_double(
      Y2Autoinstallation::Widgets::Storage::InitDrive,
      widget_id: "init_drive", value: false
    )
  end

  let(:disk_usage_widget) do
    instance_double(
      Y2Autoinstallation::Widgets::Storage::DiskUsage,
      value: "all"
    )
  end

  let(:partition_table_widget) do
    instance_double(
      Y2Autoinstallation::Widgets::Storage::DiskUsage,
      value: "gpt"
    )
  end

  before do
    allow(Y2Autoinstallation::Widgets::Storage::DiskDevice)
      .to receive(:new).and_return(disk_device_widget)
    allow(Y2Autoinstallation::Widgets::Storage::InitDrive)
      .to receive(:new).and_return(init_drive_widget)
    allow(Y2Autoinstallation::Widgets::Storage::DiskUsage)
      .to receive(:new).and_return(disk_usage_widget)
    allow(Y2Autoinstallation::Widgets::Storage::PartitionTable)
      .to receive(:new).and_return(partition_table_widget)
  end

  include_examples "CWM::Page"

  describe "#label" do
    before { drive.device = device }

    context "when the partition device is defined" do
      let(:device) { "/dev/sda" }

      it "includes the device" do
        expect(subject.label).to include("/dev/sda")
      end
    end

    context "when the partition device is not defined" do
      let(:device) { "" }

      it "does not include the device" do
        expect(subject.label).to eq("Disk")
      end
    end
  end

  describe "#store" do
    it "sets the section values" do
      subject.store
      expect(drive.device).to eq("/dev/sdb")
      expect(drive.initialize_attr).to eq(false)
      expect(drive.use).to eq("all")
      expect(drive.disklabel).to eq("gpt")
    end
  end

  describe "#handle" do
    before do
      allow(init_drive_widget).to receive(:value).and_return(init_disk)
    end

    context "when the drive must be initialized" do
      let(:init_disk) { true }

      it "disables the disk usage widget" do
        expect(disk_usage_widget).to receive(:disable)
        subject.handle("ID" => init_drive_widget.widget_id)
      end
    end

    context "when the drive should not be initialized" do
      let(:init_disk) { false }

      it "enables the disk usage widget" do
        expect(disk_usage_widget).to receive(:enable)
        subject.handle("ID" => init_drive_widget.widget_id)
      end
    end
  end
end
