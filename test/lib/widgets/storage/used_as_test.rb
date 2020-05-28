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
require "autoinstall/widgets/storage/used_as"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::UsedAs do
  subject(:widget) { described_class.new }

  include_examples "CWM::AbstractWidget"

  describe "#items" do
    let(:items) { widget.items.map { |i| i[0] } }

    it "includes :none" do
      expect(items).to include(:none)
    end

    it "includes :filesystem" do
      expect(items).to include(:filesystem)
    end

    it "includes :raid" do
      expect(items).to include(:raid)
    end

    it "includes :lvm_pv" do
      expect(items).to include(:lvm_pv)
    end

    it "includes :bcache_backing" do
      expect(items).to include(:bcache_backing)
    end

    it "includes :btrfs_member" do
      expect(items).to include(:btrfs_member)
    end
  end
end
