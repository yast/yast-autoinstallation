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
require "autoinstall/widgets/storage/partition_type"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::PartitionType do
  subject(:widget) { described_class.new }

  include_examples "CWM::ComboBox"

  describe "#items" do
    let(:items) { widget.items.map { |i| i[0] } }

    it "includes an empty item" do
      expect(items).to include("")
    end

    it "includes 'primary'" do
      expect(items).to include("primary")
    end

    it "includes 'logical'" do
      expect(items).to include("primary")
    end
  end
end
