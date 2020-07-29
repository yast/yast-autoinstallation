#!/usr/bin/env rspec

require_relative "../test_helper"
require "autoinstall/xml_checks"

describe Y2Autoinstallation::XmlChecks do

  before do
    # mock the popup to avoid accidentally displaying a popup in tests
    allow(Yast2::Popup).to receive(:show)
  end

  describe ".valid_profile?" do
    let(:valid) { true }

    before do
      allow(described_class).to receive(:check).and_return(valid)
    end

    it "checks whether a given profile is valid or not" do
      expect(described_class).to receive(:check)

      described_class.valid_profile?
    end

    context "when a valid profile is used" do
      it "returns true" do
        expect(described_class.valid_profile?).to eql(true)
      end
    end

    context "when an invalid profile is used" do
      let(:valid) { false }

      it "returns false" do
        expect(described_class.valid_profile?).to eql(false)
      end
    end
  end

  describe ".check" do
    let(:xml_name) { "foo.xml" }
    let(:schema_name) { "bar.rng" }
    let(:xml) { Pathname.new(xml_name) }
    let(:schema) { Pathname.new(schema_name) }
    let(:valid) { true }
    let(:errors) { ["ERROR"] }
    let(:errors_stored?) { true }
    let(:validator) do
      instance_double(Y2Autoinstallation::XmlValidator,
        valid?: valid, errors: errors, errors_stored?: errors_stored?, store_errors: true)
    end

    before do
      allow(Y2Autoinstallation::XmlValidator).to receive(:new).and_return(validator)
    end

    context "when the profile is a valid one" do
      it "returns true" do
        expect(described_class.check(xml, schema, "title")).to eq(true)
      end
    end

    context "when the profile is an invalid one" do
      let(:valid) { false }

      context "and it is the first time that the errors have been reported" do
        let(:errors_stored?) { false }
        let(:popup_selection) { :cancel }
        before do
          allow(Yast2::Popup).to receive(:show).and_return(popup_selection)
        end

        it "shows a popup" do
          expect(Yast2::Popup).to receive(:show)

          described_class.check(xml, schema, "title")
        end

        context "if the user continues with the errors reported" do
          let(:popup_selection) { :continue }

          it "stores the errors reported" do
            expect(validator).to receive(:store_errors)

            described_class.check(xml, schema, "title")
          end

          it "returns true" do
            expect(described_class.check(xml, schema, "title")).to eql(true)
          end
        end

        context "if the user cancel" do
          it "does not stores them" do
            expect(validator).to_not receive(:store_errors)

            described_class.check(xml, schema, "title")
          end

          it "returns false" do
            expect(described_class.check(xml, schema, "title")).to eql(false)
          end
        end
      end

      context "and the same errors were already reported" do
        it "returns true" do
          described_class.check(xml, schema, "title")
        end
      end
    end
  end
end
