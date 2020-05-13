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
require "autoinstall/widgets/storage/crypt_method"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::CryptMethod do
  subject(:widget) { described_class.new }

  include_examples "CWM::ComboBox"

  let(:items) { widget.items.map { |i| i[0] } }

  describe "#items" do
    it "includes an empty option" do
      expect(items).to include("")
    end

    it "includes 'luks1'" do
      expect(items).to include("luks1")
    end

    it "includes 'pervasive_luks2'" do
      expect(items).to include("pervasive_luks2")
    end

    it "includes 'protected_swap'" do
      expect(items).to include("protected_swap")
    end

    it "includes 'secure_swap'" do
      expect(items).to include("secure_swap")
    end

    it "includes 'random_swap'" do
      expect(items).to include("random_swap")
    end
  end

  describe "#value" do
    before do
      allow(Yast::UI).to receive(:QueryWidget).with(Id(widget.widget_id), :Value)
        .and_return(selected_value)
    end

    describe "when none is selected" do
      let(:selected_value) { "" }

      it "returns nil" do
        expect(widget.value).to be_nil
      end
    end

    describe "when any is selected" do
      let(:selected_value) { "random_swap" }

      it "returns selected value" do
        expect(widget.value).to eq(selected_value)
      end
    end
  end
end
