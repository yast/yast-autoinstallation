#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "AutoinstSoftware"
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

end
