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
require "autoinstall/widgets/storage/vg_device"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::VgDevice do
  subject(:widget) { described_class.new }

  include_examples "CWM::InputField"

  describe "value" do
    before do
      allow(Yast::UI).to receive(:QueryWidget)
        .with(Id(widget.widget_id), :Value)
        .and_return(value)
    end

    context "when current value already contains the /dev/ prefix" do
      let(:value) { "/dev/system" }

      it "returns the value as it is" do
        expect(widget.value).to eq("/dev/system")
      end
    end

    context "when current value does not contain the /dev/ prefix" do
      let(:value) { "system" }

      it "returns the value properly prefixed" do
        expect(widget.value).to eq("/dev/system")
      end
    end
  end

  describe "value=" do
    context "when given value already contains the /dev/ prefix" do
      let(:value) { "/dev/system" }

      it "updates the widget with the value as it is" do
        expect(Yast::UI).to receive(:ChangeWidget)
          .with(Id(widget.widget_id), :Value, value)

        widget.value = value
      end
    end

    context "when given value does not contain the /dev/ prefix" do
      let(:value) { "system" }

      it "updates the widget with the value properly prefixed" do
        expect(Yast::UI).to receive(:ChangeWidget)
          .with(Id(widget.widget_id), :Value, "/dev/system")

        widget.value = value
      end
    end
  end
end
