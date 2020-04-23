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
require "autoinstall/widgets/storage/vg_extent_size"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::VgExtentSize do
  subject(:widget) { described_class.new }

  include_examples "CWM::ComboBox"

  describe "#value=" do
    context "when size is given" do
      let(:size)  { 67108864 }

      it "updates the extent size with its human readable version" do
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(widget.widget_id), :Value, "64 MiB")

        widget.value = size
      end
    end

    context "when size is not given" do
      let(:size)  { nil }

      it "does nothing" do
        expect(Yast::UI).to_not receive(:ChangeWidget)

        widget.value = size
      end
    end
  end

  describe "#value" do
    before do
      allow(Yast::UI).to receive(:QueryWidget).with(Id(widget.widget_id), :Value)
        .and_return("67108864")
    end

    it "returns a human readable extent size" do
      expect(widget.value).to eq("64 MiB")
    end
  end
end
