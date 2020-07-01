#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "Profile"
Yast.import "AutoinstClone"

describe Yast::Profile do

  CUSTOM_MODULE = {
    "Name"                       => "Custom module",
    "X-SuSE-YaST-AutoInst"       => "configure",
    "X-SuSE-YaST-Group"          => "System",
    "X-SuSE-YaST-AutoInstClient" => "custom_auto"
  }.freeze

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
      allow(Yast::AutoinstFunctions).to receive(:second_stage_required?)
        .and_return(second_stage_required)
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
          { "general"  => { "mode" => { "second_stage" => false } },
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
            "files"   => [] }
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
          { "configure" => { "section2" => ["val2"] },
            "install"   => { "section1" => ["val1"] } }
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
          { "configure" => { "section1" => "val3", "section2" => ["val2"] },
            "install"   => { "section1" => ["val1"] } }
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

    it "sets general compatibility options" do
      expect(Yast::Profile).to receive(:generalCompat)
      Yast::Profile.Import(profile)
    end

    it "sets software compatibility options" do
      expect(Yast::Profile).to receive(:softwareCompat)
      Yast::Profile.Import(profile)
    end

    context "when the profile contains an aliased resource" do
      let(:custom_module) do
        CUSTOM_MODULE.merge(
          "X-SuSE-YaST-AutoInstResourceAliases" => "old_custom"
        )
      end

      before do
        # reset singleton
        allow(Yast::Desktop).to receive(:Modules)
          .and_return("custom" => custom_module)
        Singleton.__init__(Y2Autoinstallation::Entries::Registry)
      end

      context "and configuration for the resource is missing" do
        let(:profile) { { "old_custom" => { "dummy" => true } } }

        it "reuses the aliased configuration" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current.keys).to_not include("old_custom")
          expect(Yast::Profile.current["custom"]).to eq("dummy" => true)
        end
      end

      context "and configuration for the resource is present" do
        let(:profile) { { "old_custom" => { "dummy" => true }, "custom" => { "dummy" => false } } }

        it "removes the aliased configuration" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current.keys).to_not include("old_custom")
          expect(Yast::Profile.current["custom"]).to eq("dummy" => false)
        end
      end

      context "and no configuration is present" do
        let(:profile) { {} }

        it "does not set any configuration for the resource" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current.keys).to_not include("old_custom")
          expect(Yast::Profile.current.keys).to_not include("custom")
        end
      end

      context "and resource has also an alternate name" do
        let(:profile) { { "old_custom" => { "dummy" => true } } }
        let(:custom_module) do
          CUSTOM_MODULE.merge(
            "X-SuSE-YaST-AutoInstResource"        => "new_custom",
            "X-SuSE-YaST-AutoInstResourceAliases" => "old_custom"
          )
        end

        it "uses the alternate name" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current["new_custom"]).to eq("dummy" => true)
        end
      end

      context "and more than one aliased name is used" do
        let(:profile) { { "other_alias" => { "dummy" => true } } }
        let(:custom_module) do
          CUSTOM_MODULE.merge(
            "X-SuSE-YaST-AutoInstResourceAliases" => "other_alias,old_custom"
          )
        end

        it "takes into account all aliases" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current["custom"]).to eq("dummy" => true)
        end
      end
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
        Yast::Profile.remove_sections(%w[section1 section2])
        expect(Yast::Profile.current.keys).to_not include("section1")
        expect(Yast::Profile.current.keys).to_not include("section2")
      end
    end
  end

  describe "#Prepare" do
    let(:prepare) { true }
    let(:custom_module) { CUSTOM_MODULE }
    let(:custom_export) { { "key1" => "val1" } }
    let(:module_map) { { "custom" => custom_module } }

    before do
      # reset singleton
      allow(Yast::Desktop).to receive(:Modules)
        .and_return(module_map)
      Singleton.__init__(Y2Autoinstallation::Entries::Registry)
      allow(Yast::WFM).to receive(:CallFunction).and_call_original
      allow(Yast::WFM).to receive(:CallFunction)
        .with("custom_auto", ["GetModified"]).and_return(true)
      allow(Yast::WFM).to receive(:CallFunction)
        .with("custom_auto", ["Export"]).and_return(custom_export)
      allow(Yast::AutoinstClone).to receive(:General)
        .and_return("mode" => { "confirm" => false })

      subject.Reset
      subject.prepare = prepare
    end

    it "exports modules data into the current profile" do
      subject.Prepare
      expect(subject.current["custom"]).to be_kind_of(Hash)
    end

    context "when preparation is not needed" do
      let(:prepare) { false }

      it "does not set the current profile" do
        subject.Prepare
        expect(subject.current).to be_empty
      end
    end

    context "when a module is 'hidden'" do
      let(:custom_module) { CUSTOM_MODULE.merge("Hidden" => "true") }

      it "includes that module" do
        subject.Prepare
        expect(subject.current.keys).to include("custom")
      end
    end

    context "when a module exports empty data" do
      let(:custom_export) { {} }

      it "removes section from Profile" do
        subject.current["custom"] = { "bla" => "bla" }
        subject.Prepare
        expect(subject.current.keys).to_not include("custom")
      end
    end

    context "when a module has not changed" do
      before do
        allow(Yast::WFM).to receive(:CallFunction)
          .with("custom_auto", ["GetModified"]).and_return(false)
      end

      it "does not include that module" do
        subject.Prepare
        expect(subject.current).to_not have_key("custom")
      end
    end

    context "when a module has elements to merge" do
      let(:custom_export) do
        {
          "users"    => [{ "username" => "root" }],
          "defaults" => { "key1" => "val1" }
        }
      end
      let(:custom_module) do
        CUSTOM_MODULE.merge(
          "X-SuSE-YaST-AutoInstClient"     => "custom_auto",
          "X-SuSE-YaST-AutoInstMerge"      => "users,defaults",
          "X-SuSE-YaST-AutoInstMergeTypes" => "list,map"
        )
      end

      it "adds each element into the current profile" do
        subject.Prepare
        expect(subject.current["users"]).to eq(custom_export["users"])
        expect(subject.current["defaults"]).to eq(custom_export["defaults"])
      end

      context "but there is no content for some of the elements" do
        let(:custom_export) do
          { "defaults" => { "key1" => "val1" } }
        end

        it "does not include the element with no content" do
          subject.Prepare
          expect(subject.current).to_not have_key("users")
        end
      end
    end

    context "when a module uses an alternative resource name" do
      let(:custom_module) do
        CUSTOM_MODULE.merge("X-SuSE-YaST-AutoInstResource" => "alternative")
      end

      it "uses the alternative name" do
        subject.Prepare
        expect(subject.current).to include("alternative")
        expect(subject.current).to_not include("custom")
      end
    end
  end

  describe "#create" do
    let(:custom_module) { CUSTOM_MODULE }
    let(:custom_export) { { "key1" => "val1" } }
    let(:module_map) { { "custom" => custom_module } }

    before do
      # reset singleton
      allow(Yast::Desktop).to receive(:Modules)
        .and_return(module_map)
      Singleton.__init__(Y2Autoinstallation::Entries::Registry)
      allow(Yast::WFM).to receive(:CallFunction).and_call_original
      allow(Yast::WFM).to receive(:CallFunction)
        .with("custom_auto", ["Export"]).and_return(custom_export)
    end

    it "exports modules data into the current profile" do
      subject.create(["custom"])
      expect(subject.current["custom"]).to be_kind_of(Hash)
    end

    context "when a module is 'hidden'" do
      let(:custom_module) { CUSTOM_MODULE.merge("Hidden" => "true") }

      it "includes that module" do
        subject.create(["custom"])
        expect(subject.current.keys).to include("custom")
      end
    end

    context "when a module exports empty data" do
      let(:custom_export) { {} }

      it "does not include it" do
        subject.create(["custom"])
        expect(subject.current).to eq({})
      end
    end

    context "when a module has elements to merge" do
      let(:custom_export) do
        {
          "users"    => [{ "username" => "root" }],
          "defaults" => { "key1" => "val1" }
        }
      end
      let(:custom_module) do
        CUSTOM_MODULE.merge(
          "X-SuSE-YaST-AutoInstClient"     => "custom_auto",
          "X-SuSE-YaST-AutoInstMerge"      => "users,defaults",
          "X-SuSE-YaST-AutoInstMergeTypes" => "list,map"
        )
      end

      it "creates each element in the current profile" do
        subject.create(["custom"])
        expect(subject.current["users"]).to eq(custom_export["users"])
        expect(subject.current["defaults"]).to eq(custom_export["defaults"])
      end

      context "but there is no content for some of the elements" do
        let(:custom_export) do
          { "defaults" => { "key1" => "val1" } }
        end

        it "does not include the element with no content" do
          subject.create(["custom"])
          expect(subject.current).to_not have_key("users")
        end
      end
    end

    context "when a module uses an alternative resource name" do
      let(:custom_module) do
        CUSTOM_MODULE.merge("X-SuSE-YaST-AutoInstResource" => "alternative")
      end

      it "uses the alternative name" do
        subject.create("alternative")
        expect(subject.current).to include("alternative")
        expect(subject.current).to_not include("custom")
      end
    end
  end

  describe "#ReadXML" do
    let(:path) { File.join(FIXTURES_PATH, "profiles", xml_file) }

    before do
      subject.main
    end

    context "when the file is valid" do
      let(:xml_file) { "partitions.xml" }

      it "returns true" do
        expect(subject.ReadXML(path)).to eq(true)
      end

      it "imports the file content" do
        expect(subject).to receive(:Import).with(Hash)
        subject.ReadXML(path)
      end
    end

    context "when the file content is invalid" do
      let(:xml_file) { "invalid.xml" }

      before do
        allow(Yast2::Popup).to receive(:show)
      end

      it "returns false" do
        expect(subject.ReadXML(path)).to eq(false)
      end

      it "displays an error message" do
        expect(Yast2::Popup).to receive(:show)
        subject.ReadXML(path)
      end

      it "does not import the file content" do
        expect(subject).to_not receive(:Import)
        subject.ReadXML(path)
      end
    end

    context "when the content is encrypted" do
      let(:xml_file) { "profile.xml.asc" }

      before do
        allow(Yast::UI).to receive(:UserInput).and_return(:ok)
        allow(Yast::UI).to receive(:QueryWidget).with(Id(:password), :Value)
          .and_return("nots3cr3t")
        allow(Yast::UI).to receive(:OpenDialog)
      end

      around do |example|
        FileUtils.cp(File.join(FIXTURES_PATH, "profiles", "minimal.xml.asc"), path)
        example.run
        FileUtils.rm(path)
      end

      it "decrypts and imports the file content" do
        expect(subject).to receive(:Import).with(Hash)
        subject.ReadXML(path)
      end

      context "during the first stage" do
        before do
          allow(Yast::Stage).to receive(:initial).and_return(true)
        end

        it "saves the unencrypted content" do
          subject.ReadXML(path)
          expect(File.read(path)).to_not include("BEGIN PGP MESSAGE")
        end
      end
    end
  end
end
