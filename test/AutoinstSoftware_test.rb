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

  describe "selecting packages for installation" do

    before(:each) do
      allow(subject).to receive(:autoinstPackages).and_return(["a1"])
      expect(Yast::Packages).to receive(:ComputeSystemPackageList).and_return([])
      expect(Yast::Pkg).to receive(:DoProvide).with(["a1"]).and_return({"a1" => "not found"})
    end

    it "shows a popup if some packages have not been found" do
      expect(Yast::Storage).to receive(:AddPackageList).and_return(["a2","a3"])
      expect(Yast::Pkg).to receive(:DoProvide).with(["a2","a3"]).and_return({})
      expect(Yast::Report).to receive(:Error)
      subject.SelectPackagesForInstallation()
    end

    it "shows a popup for not found packages which have been selected by AY configuration only" do
      subject.Import(Yast::Profile.current["software"])
      expect(Yast::Storage).to receive(:AddPackageList).and_return(["a2","a3","a4"])
      expect(Yast::Pkg).to receive(:DoProvide).with(["a2","a3","a4"]).and_return({"a4" => "not found"})
      # a4 is not in the software/packages section
      expect(Yast::Report).to receive(:Error).with("These packages cannot be found in the software repositories:\na1: not found\n")
      subject.SelectPackagesForInstallation()
    end

    it "shows no popup if no software section has been defined in the AY configuration" do
      subject.Import({})
      expect(Yast::Storage).to receive(:AddPackageList).and_return(["a2","a3","a4"])
      expect(Yast::Pkg).to receive(:DoProvide).with(["a2","a3","a4"]).and_return({"a4" => "not found"})
      expect(Yast::Report).to_not receive(:Error)
      subject.SelectPackagesForInstallation()
    end

  end

  describe "#locked_packages" do
    before do
      expect(Yast::Pkg).to receive(:GetPackages).with(:taboo, true).and_return(["foo"])
      expect(Yast::Pkg).to receive(:GetPackages).with(:available, true).and_return(["bar"])
    end

    it "returns packages locked by user" do
      # just mock only the needed attributes
      expect(Yast::Pkg).to receive(:PkgPropertiesAll).with("foo").and_return(["transact_by" => :user, "status" => :taboo])
      expect(Yast::Pkg).to receive(:PkgPropertiesAll).with("bar").and_return(["transact_by" => :user, "status" => :available])
      expect(subject.locked_packages).to include("foo").and include("bar")
    end

    it "ignores packages changed by the solver" do
      # just mock only the needed attributes
      expect(Yast::Pkg).to receive(:PkgPropertiesAll).with("foo").and_return(["transact_by" => :solver, "status" => :taboo])
      expect(Yast::Pkg).to receive(:PkgPropertiesAll).with("bar").and_return(["transact_by" => :solver, "status" => :available])
      expect(subject.locked_packages).to be_empty
    end
  end

end
