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
require "autoinstall/widgets/storage/partition_id"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::PartitionId do
  subject(:widget) { described_class.new }

  include_examples "CWM::ComboBox"

  describe "#value" do
    before do
      allow(Yast::UI).to receive(:QueryWidget).with(Id(widget.widget_id), :Value)
        .and_return(value)
    end

    describe "when nothing is given or selected" do
      let(:value) { "" }

      it "returns empty" do
        expect(widget.value).to be_empty
      end
    end

    describe "when a value is given or selected" do
      let(:value) { "256" }

      it "returns its integer representation" do
        expect(widget.value).to eq(256)
      end
    end
  end
end
