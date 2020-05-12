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
require "cwm/rspec"

RSpec.shared_examples "Y2Autoinstallation::Widgets::Storage::BooleanSelector" do
  include_examples "CWM::ComboBox"

  let(:widget_id) { Id(subject.widget_id) }

  describe "#items" do
    let(:items_ids) { subject.items.map { |i| i[0] } }

    it "includes the 'true' option" do
      expect(items_ids).to include("true")
    end

    it "includes the 'false' option" do
      expect(items_ids).to include("false")
    end

    context "when #include_blank? is true" do
      before do
        allow(subject).to receive(:include_blank?).and_return(true)
      end

      it "includes an empty option" do
        expect(items_ids).to include("")
      end
    end

    context "when #include_blank? is false" do
      before do
        allow(subject).to receive(:include_blank?).and_return(false)
      end

      it "does not include an empty option" do
        expect(items_ids).to_not include("")
      end
    end
  end

  describe "#value" do
    before do
      allow(Yast::UI).to receive(:QueryWidget).with(widget_id, :Value)
        .and_return(selected)
    end

    context "when the empty option has been selected" do
      let(:selected) { "" }

      it "returns nil" do
        expect(subject.value).to be_nil
      end
    end

    context "when 'Yes' has been selected" do
      let(:selected) { "true" }

      it "returns true" do
        expect(subject.value).to eq(true)
      end
    end

    context "when 'No' has been selected" do
      let(:selected) { "false" }

      it "returns false" do
        expect(subject.value).to eq(false)
      end
    end
  end

  describe "#value=" do
    context "when no value is given" do
      it "selects the empty option" do
        expect(Yast::UI).to receive(:ChangeWidget).with(widget_id, :Value, "")

        subject.value = nil
      end
    end

    context "when empty value is given" do
      it "selects the empty option" do
        expect(Yast::UI).to receive(:ChangeWidget).with(widget_id, :Value, "")

        subject.value = ""
      end
    end

    context "when 'true' is given" do
      it "selects 'yes' option" do
        expect(Yast::UI).to receive(:ChangeWidget).with(widget_id, :Value, "true")

        subject.value = true
      end
    end

    context "when 'false' is given" do
      it "selects 'no' option" do
        expect(Yast::UI).to receive(:ChangeWidget).with(widget_id, :Value, "false")

        subject.value = false
      end
    end
  end

  describe "#include_blank?" do
    it "returns a Boolean value" do
      expect([true, false]).to include(subject.include_blank?)
    end
  end
end
