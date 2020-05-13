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
require "autoinstall/widgets/storage/lvm_page"
require "autoinstall/presenters"
require "y2storage/autoinst_profile"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::LvmPage do
  subject(:lvm_page) { described_class.new(drive) }

  include_examples "CWM::Page"

  let(:drive) { Y2Autoinstallation::Presenters::Drive.new(partitioning.drives.first) }

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
      [partition_hash]
    )
  end

  let(:partition_hash) do
    {
      "type"      => :CT_LVM,
      "device"    => device,
      "is_lvm_vg" => is_lvm_vg,
      "pesize"    => pesize
    }
  end

  let(:device) { "/dev/system" }
  let(:is_lvm_vg) { true }
  let(:pesize) { 64 }

  let(:vg_device_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::VgDevice, value: device)
  end
  let(:is_lvm_vg_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::IsLvmVg, value: is_lvm_vg)
  end
  let(:pesize_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::Pesize, value: pesize)
  end

  before do
    allow(Y2Autoinstallation::Widgets::Storage::VgDevice)
      .to receive(:new).and_return(vg_device_widget)
    allow(Y2Autoinstallation::Widgets::Storage::IsLvmVg)
      .to receive(:new).and_return(is_lvm_vg_widget)
    allow(Y2Autoinstallation::Widgets::Storage::Pesize)
      .to receive(:new).and_return(pesize_widget)

    allow(vg_device_widget).to receive(:value=)
    allow(vg_device_widget).to receive(:value=)
    allow(is_lvm_vg_widget).to receive(:value=)
    allow(pesize_widget).to receive(:value=)
  end

  describe "#init" do
    it "sets vg_device" do
      expect(vg_device_widget).to receive(:value=).with(device)
      lvm_page.init
    end

    it "sets is_lvm_vg" do
      expect(is_lvm_vg_widget).to receive(:value=).with(is_lvm_vg)
      lvm_page.init
    end

    it "sets the vg physical extent size" do
      expect(pesize_widget).to receive(:value=).with(pesize)
      lvm_page.init
    end
  end

  describe "#values" do
    it "includes device" do
      expect(lvm_page.values).to include("device" => device)
    end

    it "includes is_lvm_vg" do
      expect(lvm_page.values).to include("is_lvm_vg" => is_lvm_vg)
    end

    it "includes pesize" do
      expect(lvm_page.values).to include("pesize" => pesize)
    end
  end
end
