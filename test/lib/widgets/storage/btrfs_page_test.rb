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
require "autoinstall/presenters"
require "autoinstall/widgets/storage/btrfs_page"
require "y2storage/autoinst_profile"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::BtrfsPage do
  subject(:btrfs_page) { described_class.new(drive) }

  include_examples "CWM::Page"

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
      [
        {
          "type"          => :CT_BCACHE,
          "device"        => "root_fs",
          "btrfs_options" => {
            "data_raid_level"     => "raid1",
            "metadata_raid_level" => "raid1"
          }
        }
      ]
    )
  end
  let(:drive) { Y2Autoinstallation::Presenters::Drive.new(partitioning.drives.first) }

  let(:device_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::BtrfsDevice, value: "rootfs")
  end
  let(:data_raid_level_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::DataRaidLevel, value: "raid6")
  end
  let(:metadata_raid_level_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::MetadataRaidLevel, value: "raid6")
  end

  before do
    allow(Y2Autoinstallation::Widgets::Storage::BtrfsDevice)
      .to receive(:new).and_return(device_widget)
    allow(Y2Autoinstallation::Widgets::Storage::DataRaidLevel)
      .to receive(:new).and_return(data_raid_level_widget)
    allow(Y2Autoinstallation::Widgets::Storage::MetadataRaidLevel)
      .to receive(:new).and_return(metadata_raid_level_widget)
    allow(device_widget).to receive(:value=)
    allow(data_raid_level_widget).to receive(:value=)
    allow(metadata_raid_level_widget).to receive(:value=)
  end

  describe "#init" do
    it "initializes Btrfs attributes" do
      expect(device_widget).to receive(:value=).with("root_fs")
      expect(data_raid_level_widget).to receive(:value=).with("raid1")
      expect(metadata_raid_level_widget).to receive(:value=).with("raid1")
      btrfs_page.init
    end
  end

  describe "#store" do
    it "sets Btrfs drive section attributes" do
      btrfs_page.store

      expect(drive.device).to eq("rootfs")
      expect(drive.btrfs_options.data_raid_level).to eq("raid6")
      expect(drive.btrfs_options.metadata_raid_level).to eq("raid6")
    end
  end
end
