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
          expect(packages_list).to eq(["autoyast2-installation"])
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

    context "when the 'files' section is present" do
      let(:profile) { { "files" => [] } }

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

  describe "#add_sections_to_skip_list" do
    context "when list is empty" do
      before do
        allow(Yast::Profile).to receive(:get_sections_from_skip_list).and_return([])
      end

      context "and an array is given" do
        it "adds all sections to the skip list" do
          expect(Yast::SCR).to receive(:Write)
            .with(path(".target.string"), Yast::ProfileClass::SKIP_LIST_PATH, "section1\nsection2")
            .and_return(true)
          expect(Yast::Profile.add_sections_to_skip_list(%w(section1 section2)))
            .to eq(%w(section1 section2))
        end
      end

      context "and a single section is given" do
        it "adds the section to the skip list" do
          expect(Yast::SCR).to receive(:Write)
            .with(path(".target.string"), Yast::ProfileClass::SKIP_LIST_PATH, "section1")
            .and_return(true)
          expect(Yast::Profile.add_sections_to_skip_list("section1"))
            .to eq(["section1"])
        end
      end
    end

    context "when list is not empty" do
      before do
        allow(Yast::Profile).to receive(:get_sections_from_skip_list).and_return(["old_section"])
      end

      context "and an array is given" do
        it "adds new sections to the skip list" do
          expect(Yast::SCR).to receive(:Write)
            .with(path(".target.string"), Yast::ProfileClass::SKIP_LIST_PATH, "old_section\nsection1\nsection2")
            .and_return(true)
          expect(Yast::Profile.add_sections_to_skip_list(%w(old_section section1 section2)))
            .to eq(%w(old_section section1 section2))
        end
      end

      context "and a single section is given" do
        it "adds the section to the skip list" do
          expect(Yast::SCR).to receive(:Write)
            .with(path(".target.string"), Yast::ProfileClass::SKIP_LIST_PATH, "old_section\nsection1")
            .and_return(true)
          expect(Yast::Profile.add_sections_to_skip_list(%w(section1)))
            .to eq(%w(old_section section1))
        end
      end
    end

    context "when the element could not be written" do
      it "raises and exception" do
        expect(Yast::SCR).to receive(:Write)
          .with(path(".target.string"), Yast::ProfileClass::SKIP_LIST_PATH, "section1")
          .and_return(false)
          expect { Yast::Profile.add_sections_to_skip_list("section1") }.to raise_error
      end
    end
  end

  describe "#get_sections_from_skip_list" do
    context "when skip list does not exist" do
      it "returns and empty array" do
        expect(Yast::SCR).to receive(:Read)
          .with(path(".target.string"), Yast::ProfileClass::SKIP_LIST_PATH)
          .and_return(nil)
        expect(Yast::Profile.get_sections_from_skip_list).to eq([])
      end
    end

    context "when skip list exists" do
      it "returns all included sections" do
        expect(Yast::SCR).to receive(:Read)
          .with(path(".target.string"), Yast::ProfileClass::SKIP_LIST_PATH)
          .and_return("section1\nsection2")
        expect(Yast::Profile.get_sections_from_skip_list).to eq(%w(section1 section2))
      end
    end
  end

  describe "#save_skip_list" do
    context "if skip list does not exists" do
      it "does nothing" do
        expect(::File).to receive(:exist?).with(Yast::ProfileClass::SKIP_LIST_PATH).and_return(false)
        expect(::FileUtils).to_not receive(:cp)
        Yast::Profile.save_skip_list
      end
    end

    context "if skip list exists" do
      before do
        allow(::File).to receive(:exist?).with(Yast::ProfileClass::SKIP_LIST_PATH).and_return(true)
      end

      context "and no destination is given" do
        it "saves to the default destination (Installation.destdir + SKIP_LIST_PATH)" do
          expect(::FileUtils).to receive(:cp)
            .with(Yast::ProfileClass::SKIP_LIST_PATH, File.join(Yast::Installation.destdir, Yast::ProfileClass::SKIP_LIST_PATH))
          Yast::Profile.save_skip_list
        end
      end

      context "and some destination is given" do
        it "copy the file to given destination" do
          expect(::FileUtils).to receive(:cp)
            .with(Yast::ProfileClass::SKIP_LIST_PATH, "/some/destination")
          Yast::Profile.save_skip_list("/some/destination")
        end
      end
    end
  end
end
