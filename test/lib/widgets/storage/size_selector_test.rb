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
require "autoinstall/widgets/storage/size_selector"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::SizeSelector do
  subject(:widget) { described_class.new }

  include_examples "CWM::ComboBox"

  describe "#items" do
    let(:include_blank) { true }
    let(:include_auto)  { true }
    let(:include_max)   { true }

    before do
      allow(widget).to receive(:include_blank?).and_return(include_blank)
      allow(widget).to receive(:include_auto?).and_return(include_auto)
      allow(widget).to receive(:include_max?).and_return(include_max)
    end

    context "when #include_blank? is true" do
      it "includes an empty option as first item" do
        expect(widget.items.first).to eq(["", ""])
      end
    end

    context "when #include_blank? is false" do
      let(:include_blank)  { false }

      it "does not include an empty option as first item" do
        expect(widget.items.first).to_not eq(["", ""])
      end
    end

    context "when #include_auto? is true" do
      it "includes the 'auto' option" do
        expect(widget.items).to include(["auto", "auto"])
      end
    end

    context "when #include_auto? is false" do
      let(:include_auto) { false }

      it "does not include the 'auto' option" do
        expect(widget.items).to_not include(["auto", "auto"])
      end
    end

    context "when #include_max? is true" do
      it "includes the 'max' option" do
        expect(widget.items).to include(["max", "max"])
      end
    end

    context "when #include_max? is false" do
      let(:include_max) { false }

      it "does not include the 'max' option" do
        expect(widget.items).to_not include(["max", "max"])
      end
    end
  end

  describe "#value" do
    before do
      allow(Yast::UI).to receive(:QueryWidget)
        .with(Id(widget.widget_id), :Value)
        .and_return(size)
    end

    context "when size is a valid disk size" do
      let(:size) { "10737418240" }

      it "returns the human readable disk size" do
        expect(widget.value).to eq("10.00 GiB")
      end
    end

    context "when size is a not valid disk size" do
      let(:size) { "max" }

      it "returns the value as it is" do
        expect(widget.value).to eq("max")
      end
    end

    context "when #legacy_units? is true" do
      let(:legacy_units) { true }

      before do
        allow(widget).to receive(:legacy_units?).and_return(legacy_units)
      end

      context "and a 2 units size is given" do
        let(:size) { "1 TB" }

        it "does consider it as if an International Size Unit was given" do
          expect(widget.value).to eq("1.00 TiB")
        end
      end

      context "and an International System Unit size is given" do
        let(:size) { "1 TiB" }

        it "returns formatted size" do
          expect(widget.value).to eq("1.00 TiB")
        end
      end
    end

    context "when #legacy_units? is false" do
      let(:legacy_units) { false }

      before do
        allow(widget).to receive(:legacy_units?).and_return(legacy_units)
      end

      context "and a 2 units size is given" do
        let(:size) { "1 TB" }

        it "returns its equivalent International Size Unit size" do
          expect(widget.value).to eq("0.91 TiB")
        end
      end

      context "and an International System Unit size is given" do
        let(:size) { "1 TiB" }

        it "returns formatted size" do
          expect(widget.value).to eq("1.00 TiB")
        end
      end
    end
  end

  describe "#value=" do
    context "when given value is a valid disk size" do
      let(:size)  { 67108864 }

      it "updates the widget value using its human readable version" do
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(widget.widget_id), :Value, "64.00 MiB")

        widget.value = size
      end
    end

    context "when given value is a not valid disk size" do
      let(:size)  { "max" }

      it "updates the widget with the given value" do
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(widget.widget_id), :Value, "max")

        widget.value = size
      end
    end
  end
end
