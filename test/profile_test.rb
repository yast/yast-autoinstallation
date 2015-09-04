#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "Profile"

describe Yast::Profile do
  subject { Yast::Profile }

  def items_list(items)
    Yast::Profile.current["software"][items] || []
  end

  def packages_list
    items_list("packages")
  end

  def patterns_list
    items_list("patterns")
  end

  describe "#softwareCompat" do
    before do
      Yast::Profile.current = profile
      allow(Yast::InstFunctions).to receive(:second_stage_required?).and_return(second_stage_required)
    end

    let(:second_stage_required) { true }

    context "when autoyast2-installation is not selected to be installed" do
      let(:profile) { { "software" => { "packages" => [] } } }

      context "and second stage is required" do
        it "adds 'autoyast2-installation' to packages list" do
          Yast::Profile.softwareCompat
          expect(packages_list).to include("autoyast2-installation")
        end
      end

      context "and second stage is not required" do
        let(:second_stage_required) { false }

        it "does not add 'autoyast2-installation' to packages list" do
          Yast::Profile.softwareCompat
          expect(packages_list).to_not eq(["autoyast2-installation"])
        end
      end

      context "and second stage is disabled on the profile itself" do
        let(:profile) do
          { "general" => { "mode" => { "second_stage" => false } },
            "software" => { "packages" => [] } }
        end

        it "does not add 'autoyast2-installation' to packages list" do
          Yast::Profile.softwareCompat
          expect(packages_list).to_not include(["autoyast2-installation"])
        end
      end
    end

    context "when some section handled by a client included in autoyast2 package is present" do
      let(:profile) { { "scripts" => [] } }

      context "and second stage is required" do
        it "adds 'autoyast2' to packages list" do
          Yast::Profile.softwareCompat
          expect(packages_list).to include("autoyast2")
        end
      end

      context "and second stage is not required" do
        let(:second_stage_required) { false }

        it "does not add 'autoyast2' to packages list" do
          Yast::Profile.softwareCompat
          expect(packages_list).to_not include("autoyast2")
        end
      end

      context "and second stage is disabled on the profile itself" do
        let(:profile) do
          { "general" => { "mode" => { "second_stage" => false } },
            "files" => [] }
        end

        it "does not add 'autoyast2' to packages list" do
          Yast::Profile.softwareCompat
          expect(packages_list).to_not include(["autoyast2-installation"])
        end
      end
    end

    context "when the software patterns section is empty" do
      let(:profile) { { "software" => { "patterns" => [] } } }

      it "adds 'base' pattern" do
        Yast::Profile.softwareCompat
        expect(patterns_list).to include("base")
      end
    end

    context "when the software patterns section is missing" do
      let(:profile) { {} }

      it "adds 'base' pattern" do
        Yast::Profile.softwareCompat
        expect(patterns_list).to include("base")
      end
    end
  end

  describe "#Import" do
    let(:profile) { {} }

    context "when profile is given in the old format" do
      context "and 'install' key is present" do
        let(:profile) { { "install" =>  { "section1" => ["val1"] } } }

        it "move 'install' items to the root of the profile" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current["section1"]).to eq(["val1"])
          expect(Yast::Profile.current["install"]).to be_nil
        end
      end

      context "and 'configure' key is present" do
        let(:profile) { { "configure" =>  { "section2" => ["val2"] } } }

        it "move 'configure' items to the root of the profile" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current["section2"]).to eq(["val2"])
          expect(Yast::Profile.current["configure"]).to be_nil
        end
      end

      context "when both keys are present" do
        let(:profile) do
          { "configure" =>  { "section2" => ["val2"] },
            "install" =>    { "section1" => ["val1"] } }
        end

        it "merge them into the root of the profile" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current["section1"]).to eq(["val1"])
          expect(Yast::Profile.current["section2"]).to eq(["val2"])
          expect(Yast::Profile.current["install"]).to be_nil
          expect(Yast::Profile.current["configure"]).to be_nil
        end
      end

      context "when both keys are present and some section is duplicated" do
        let(:profile) do
          { "configure" =>  { "section1" => "val3", "section2" => ["val2"] },
            "install" =>    { "section1" => ["val1"] } }
        end

        it "merges them into the root of the profile giving precedence to 'installation' section" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current["section1"]).to eq(["val1"])
          expect(Yast::Profile.current["section2"]).to eq(["val2"])
          expect(Yast::Profile.current["install"]).to be_nil
          expect(Yast::Profile.current["configure"]).to be_nil
        end
      end
    end

    it "sets storage compatibility options" do
      expect(Yast::Profile).to receive(:storageLibCompat)
      Yast::Profile.Import(profile)
    end

    it "sets general compatibility options" do
      expect(Yast::Profile).to receive(:generalCompat)
      Yast::Profile.Import(profile)
    end

    it "sets software compatibility options" do
      expect(Yast::Profile).to receive(:softwareCompat)
      Yast::Profile.Import(profile)
    end
  end

  describe "#remove_sections" do
    before do
      Yast::Profile.Import("section1" => "val1", "section2" => "val2")
    end

    context "when a single section is given" do
      it "removes that section" do
        Yast::Profile.remove_sections("section1")
        expect(Yast::Profile.current.keys).to_not include("section1")
        expect(Yast::Profile.current.keys).to include("section2")
      end
    end

    context "when multiple sections are given" do
      it "removes every given section" do
        Yast::Profile.remove_sections(%w(section1 section2))
        expect(Yast::Profile.current.keys).to_not include("section1")
        expect(Yast::Profile.current.keys).to_not include("section2")
      end
    end
  end
end
