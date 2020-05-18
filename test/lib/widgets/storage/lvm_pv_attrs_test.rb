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
require "autoinstall/storage_controller"
require "autoinstall/widgets/storage/lvm_pv_attrs"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::LvmPvAttrs do
  subject(:widget) { described_class.new(controller, section) }

  include_examples "CWM::CustomWidget"

  let(:controller) { Y2Autoinstallation::StorageController.new(partitioning) }
  let(:section) { Y2Storage::AutoinstProfile::PartitionSection.new }

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
      [{ "device" => "/dev/system", "type" => :CT_LVM, "pesize" => "64" }]
    )
  end

  let(:lvm_group_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::LvmGroup)
  end

  before do
    allow(lvm_group_widget).to receive(:items=)
    allow(lvm_group_widget).to receive(:value=)
    allow(lvm_group_widget).to receive(:value)
    allow(Y2Autoinstallation::Widgets::Storage::LvmGroup)
      .to receive(:new)
      .and_return(lvm_group_widget)
  end

  describe "#init" do
    it "sets the available lvm groups" do
      expect(lvm_group_widget).to receive(:items=).with(["system"])
      widget.init
    end

    it "sets the lvm group initial value" do
      expect(lvm_group_widget).to receive(:value=)
      widget.init
    end
  end

  describe "#values" do
    it "includes `lvm_group`" do
      expect(widget.values).to match(a_hash_including("lvm_group" => anything))
    end
  end
end
