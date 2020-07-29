#!/usr/bin/env rspec

require_relative "../test_helper"
require "autoinstall/xml_validator"

describe Y2Autoinstallation::XmlValidator do
  let(:xml_name) { "foo.xml" }
  let(:schema_name) { "bar.rng" }
  let(:xml) { Pathname.new(xml_name) }
  let(:schema) { Pathname.new(schema_name) }
  subject { Y2Autoinstallation::XmlValidator.new(xml_name, schema_name) }

  describe "#valid?" do
    it "returns true if Yast::XML.validate returns no errors" do
      expect(Yast::XML).to receive(:validate).with(xml, schema).and_return([])
      expect(subject.valid?).to be true
    end

    it "returns false if Yast::XML.validate returns some error" do
      expect(Yast::XML).to receive(:validate).with(xml, schema).and_return(["ERROR"])
      expect(subject.valid?).to be false
    end

    it "returns false if Yast::XML.validate fails with parse error" do
      expect(Yast::XML).to receive(:validate).with(xml, schema)
        .and_raise(Yast::XMLDeserializationError)
      expect(subject.valid?).to be false
    end
  end

  describe "#errors" do
    it "returns empty list if Yast::XML.validate returns no errors" do
      expect(Yast::XML).to receive(:validate).with(xml, schema).and_return([])
      expect(subject.errors).to eq([])
    end

    it "returns errors from Yast::XML.validate" do
      expect(Yast::XML).to receive(:validate).with(xml, schema).and_return(["ERROR"])
      expect(subject.errors).to eq(["ERROR"])
    end

    it "returns the parse false if Yast::XML.validate fails with parse error" do
      expect(Yast::XML).to receive(:validate).with(xml, schema)
        .and_raise(Yast::XMLDeserializationError.new("error"))
      expect(subject.errors).to eq(["error"])
    end
  end

  describe "#store_errors" do
    it "writes current errors to the filesystem in YAML format" do
      stub_const("Y2Autoinstallation::XmlValidator::STORE_DIR", FIXTURES_PATH)
      errors_file_path = subject.send(:errors_file_path)
      expect(File).to receive(:write).with(errors_file_path, subject.errors.to_yaml)

      subject.store_errors
    end
  end

  describe "#errors_stored?" do
    before do
      stub_const("Y2Autoinstallation::XmlValidator::STORE_DIR", FIXTURES_PATH)
    end

    after do
      errors_file_path = subject.send(:errors_file_path)
      File.delete(errors_file_path) if File.exist?(errors_file_path)
    end

    context "when there is already a file for the errors reported" do
      it "returns true" do
        subject.store_errors
        expect(subject.errors_stored?).to eq(true)
      end
    end

    context "when there is no file with the reported errors" do
      it "returns false" do
        expect(subject.errors_stored?).to eq(false)
      end
    end
  end
end
