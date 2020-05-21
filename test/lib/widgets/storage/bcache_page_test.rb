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
require "autoinstall/widgets/storage/bcache_page"
require "y2storage/autoinst_profile"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::BcachePage do
  subject(:bcache_page) { described_class.new(drive) }

  include_examples "CWM::Page"

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
      [
        {
          "type"           => :CT_BCACHE,
          "device"         => "/dev/bcache0",
          "bcache_options" => {
            "cache_mode" => "writethrough"
          }
        }
      ]
    )
  end
  let(:drive) { Y2Autoinstallation::Presenters::Drive.new(partitioning.drives.first) }

  let(:device_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::BcacheDevice, value: "/dev/bcache1")
  end
  let(:cache_mode_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::CacheMode, value: "writeback")
  end

  before do
    allow(Y2Autoinstallation::Widgets::Storage::BcacheDevice)
      .to receive(:new).and_return(device_widget)
    allow(Y2Autoinstallation::Widgets::Storage::CacheMode)
      .to receive(:new).and_return(cache_mode_widget)
    allow(device_widget).to receive(:value=)
    allow(cache_mode_widget).to receive(:value=)
  end

  describe "#init" do
    it "initializes bcache attributes" do
      expect(device_widget).to receive(:value=).with("/dev/bcache0")
      expect(cache_mode_widget).to receive(:value=).with("writethrough")
      bcache_page.init
    end
  end

  describe "#store" do
    it "sets bcache drive section attributes" do
      bcache_page.store

      expect(drive.device).to eq("/dev/bcache1")
      expect(drive.bcache_options.cache_mode).to eq("writeback")
    end
  end
end
