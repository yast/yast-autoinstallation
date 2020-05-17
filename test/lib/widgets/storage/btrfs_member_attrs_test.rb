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
require "y2storage"
require "autoinstall/presenters"
require "autoinstall/widgets/storage/btrfs_member_attrs"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::BtrfsMemberAttrs do
  subject(:widget) { described_class.new(section) }

  include_examples "CWM::CustomWidget"

  let(:drive) { Y2Autoinstallation::Presenters::Drive.new(partitioning.drives.first) }
  let(:section) { drive.partitions.first }

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
      [
        { "type" => :CT_DISK, "partitions" => [{}] },
        { "type" => :CT_BTRFS, "device" => "root_fs" }
      ]
    )
  end

  let(:btrfs_name_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::BtrfsName, value: "rootfs")
  end

  before do
    allow(btrfs_name_widget).to receive(:items=)
    allow(btrfs_name_widget).to receive(:value=)
    allow(Y2Autoinstallation::Widgets::Storage::BtrfsName)
      .to receive(:new)
      .and_return(btrfs_name_widget)
  end

  describe "#init" do
    it "sets the available Btrfs filesystems" do
      expect(btrfs_name_widget).to receive(:items=).with(["root_fs"])
      widget.init
    end

    it "sets the Btrfs name initial valaue" do
      expect(btrfs_name_widget).to receive(:value=)
      widget.init
    end
  end

  describe "#values" do
    it "includes btrfs_name" do
      expect(widget.values).to include("btrfs_name" => "rootfs")
    end
  end
end
