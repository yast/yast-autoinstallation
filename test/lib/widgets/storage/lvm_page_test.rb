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
  subject { described_class.new(drive) }

  include_examples "CWM::Page"

  let(:drive) { Y2Autoinstallation::Presenters::Drive.new(partitioning.drives.first) }

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
      [{ "device" => "/dev/system", "type" => :CT_LVM, "pesize" => "64" }]
    )
  end
  let(:vg_device_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::VgDevice)
  end

  let(:vg_pesize_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::VgExtentSize)
  end

  before do
    allow(Y2Autoinstallation::Widgets::Storage::VgDevice)
      .to receive(:new).and_return(vg_device_widget)
    allow(Y2Autoinstallation::Widgets::Storage::VgExtentSize)
      .to receive(:new).and_return(vg_pesize_widget)

    allow(vg_device_widget).to receive(:value=)
    allow(vg_pesize_widget).to receive(:value=)
  end

  describe "#init" do
    it "sets the vg physical extent size" do
      expect(vg_pesize_widget).to receive(:value=)
      subject.init
    end
  end
end
