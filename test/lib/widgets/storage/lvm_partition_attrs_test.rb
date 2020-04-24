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
require "autoinstall/widgets/storage/lvm_partition_attrs"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::LvmPartitionAttrs do
  subject(:widget) { described_class.new(controller, section) }

  let(:controller) do
    instance_double(Y2Autoinstallation::StorageController)
  end

  let(:section) do
    Y2Storage::AutoinstProfile::PartitionSection.new
  end

  let(:lv_name_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::LvName, value: lv_name)
  end

  include_examples "CWM::CustomWidget"

  describe "#values" do
    let(:lv_name) { "lv-home" }

    before do
      allow(Y2Autoinstallation::Widgets::Storage::LvName).to receive(:new)
        .and_return(lv_name_widget)
    end

    it "includes lv_name" do
      expect(widget.values).to include("lv_name" => "lv-home")
    end
  end
end
