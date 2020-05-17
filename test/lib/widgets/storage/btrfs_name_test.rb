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
require "autoinstall/widgets/storage/btrfs_name"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::BtrfsName do
  subject(:widget) { described_class.new }

  include_examples "CWM::ComboBox"

  describe "#items=" do
    let(:devices)   { ["rootfs", "homefs"] }

    it "updates the widget with given filesystems including an empty option" do
      expect(widget).to receive(:change_items).with(
        [
          ["", ""],
          ["rootfs", "rootfs"],
          ["homefs", "homefs"]
        ]
      )

      widget.items = devices
    end
  end
end
