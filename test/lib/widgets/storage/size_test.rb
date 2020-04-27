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
require "autoinstall/widgets/storage/size"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::Size do
  subject(:widget) { described_class.new }

  include_examples "CWM::ComboBox"

  describe "#value" do
    before do
      allow(Yast::UI).to receive(:QueryWidget)
        .with(Id(widget.widget_id), :Value)
        .and_return(size)
    end

    context "when size is a valid DiskSize" do
      let(:size) { "10737418240" }

      it "returns the human readable DiskSize" do
        expect(widget.value).to eq("10.00 GiB")
      end
    end

    context "when size is a not valid DiskSize" do
      let(:size) { "max" }

      it "returns the value as it is" do
        expect(widget.value).to eq("max")
      end
    end
  end
end
