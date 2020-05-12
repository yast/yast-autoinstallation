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
require "autoinstall/widgets/storage/lvm_partition_attrs"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::LvmPartitionAttrs do
  subject(:widget) { described_class.new(section) }

  include_examples "CWM::CustomWidget"

  let(:section) do
    Y2Storage::AutoinstProfile::PartitionSection.new
  end

  describe "#values" do
    let(:lv_name_widget) do
      instance_double(Y2Autoinstallation::Widgets::Storage::LvName, value: "lv-home")
    end
    let(:pool_widget) do
      instance_double(Y2Autoinstallation::Widgets::Storage::Pool, value: false)
    end
    let(:used_pool_widget) do
      instance_double(Y2Autoinstallation::Widgets::Storage::UsedPool, value: "my_thin_pool")
    end
    let(:stripes_widget) do
      instance_double(Y2Autoinstallation::Widgets::Storage::Stripes, value: 2)
    end
    let(:stripesize_widget) do
      instance_double(Y2Autoinstallation::Widgets::Storage::Stripesize, value: 4)
    end

    before do
      allow(Y2Autoinstallation::Widgets::Storage::LvName).to receive(:new)
        .and_return(lv_name_widget)
      allow(Y2Autoinstallation::Widgets::Storage::Pool).to receive(:new)
        .and_return(pool_widget)
      allow(Y2Autoinstallation::Widgets::Storage::UsedPool).to receive(:new)
        .and_return(used_pool_widget)
      allow(Y2Autoinstallation::Widgets::Storage::Stripes).to receive(:new)
        .and_return(stripes_widget)
      allow(Y2Autoinstallation::Widgets::Storage::Stripesize).to receive(:new)
        .and_return(stripesize_widget)
    end

    it "includes lv_name" do
      expect(widget.values).to include("lv_name" => "lv-home")
    end

    it "includes pool" do
      expect(widget.values).to include("pool" => false)
    end

    it "includes used_pool" do
      expect(widget.values).to include("used_pool" => "my_thin_pool")
    end

    it "includes stripes" do
      expect(widget.values).to include("stripes" => 2)
    end

    it "includes stripe_size" do
      expect(widget.values).to include("stripe_size" => 4)
    end
  end
end
