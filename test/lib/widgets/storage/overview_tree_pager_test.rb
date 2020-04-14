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

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
      [{ "mount" => "/dev/sda" }]
    )
  end

  let(:controller) { Y2Autoinstallation::StorageController.new(partitioning) }

  describe "#items" do
    it "returns one item for each drive" do
      items = subject.items
      expect(items.size).to eq(1)
    end
  end
end
