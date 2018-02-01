#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "AutoinstSoftware"
Yast.import "AutoinstData"
Yast.import "Profile"

describe Yast::AutoinstSoftware do
  subject { Yast::AutoinstSoftware }
  FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures')
  let(:profile) { File.join(FIXTURES_PATH, 'profiles', 'software.xml') }

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

  describe "selecting packages for installation" do

    before(:each) do
      allow(subject).to receive(:autoinstPackages).and_return(["a1"])
      expect(Yast::Packages).to receive(:ComputeSystemPackageList).and_return([])
      allow(subject).to receive(:autoinstPackages).and_return(["a1"])
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

end
