#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "AutoinstSoftware"
Yast.import "AutoinstData"
Yast.import "Profile"

describe Yast::AutoinstSoftware do

  subject { Yast::AutoinstSoftware }

  let(:profile) { FIXTURES_PATH.join("profiles", "software.xml").to_s }

  before(:each) do
    Yast::Profile.ReadXML(profile)
  end

  describe "post-software installation" do
    it "installs packages only if they have not already been installed" do
      Yast::AutoinstData.post_packages = ["a2"]
      expect(Yast::PackageSystem).to receive(:Installed).with("a1").and_return(false)
      expect(Yast::PackageSystem).to receive(:Installed).with("a2").and_return(false)
      expect(Yast::PackageSystem).to receive(:Installed).with("a3").and_return(true)
      subject.Import(Yast::Profile.current["software"])

      expect(Yast::AutoinstData.send(:post_packages)).to eq(["a1","a2"])
    end
  end

  describe "#Export" do
    it "puts product definition into the exported profile" do
      expect(Yast::Product)
        .to receive(:FindBaseProducts)
        .and_return([{ "short_name" => "LeanOS" }])

      profile = subject.Export

      expect(profile).to have_key("products")
      expect(profile["products"]).to eql ["LeanOS"]
    end

    it "raises an error when multiple products were found" do
      expect(Yast::Product)
        .to receive(:FindBaseProducts)
        .and_return(
          [
            { "short_name" => "LeanOS" },
            { "short_name" => "AgileOS" }
          ]
        )

      expect { subject.Export }.to raise_error(RuntimeError, "Found multiple base products")
    end
  end
end
