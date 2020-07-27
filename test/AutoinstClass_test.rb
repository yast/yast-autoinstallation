#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "AutoinstClass"

describe "Yast::AutoinstClass" do

  subject { Yast::AutoinstClass }

  ROOT_PATH = File.expand_path("..", __dir__)
  CLASS_DIR = File.join(FIXTURES_PATH, "classes")
  CLASS_PATH = File.join(CLASS_DIR, "classes.xml")

  let(:settings) { [{ "class_name" => "swap", "configuration" => "largeswap.xml" }] }

  before(:each) do
    subject.class_dir = CLASS_DIR
    allow(Y2Autoinstallation::XmlChecks).to receive(:valid_classes?).and_return(true)
  end

  describe "#Read" do
    context "when some class definition exists" do
      it "read content into @Classes" do
        subject.Read
        expect(subject.Classes).to_not be_empty
      end

      it "returns nil" do
        expect(subject.Read).to be_nil
      end
    end

    context "when class definition is not valid" do
      it "sets Classes to []" do
        allow(Yast::XML).to receive(:XMLToYCPFile).and_raise(Yast::XMLDeserializationError)
        subject.Read
        expect(subject.Classes).to eq([])
      end

      it "returns nil" do
        allow(Yast::XML).to receive(:XMLToYCPFile).and_raise(Yast::XMLDeserializationError)
        expect(subject.Read).to be_nil
      end

    end

    context "when classes definition file does not exist" do
      before(:each) do
        allow(Yast::SCR).to receive(:Read).with(Yast::Path.new(".target.size"), CLASS_PATH)
          .and_return(-1)
      end

      it "sets Classes to []" do
        subject.Read
        expect(subject.Classes).to eq([])
      end

      it "returns nil" do
        expect(subject.Read).to be_nil
      end
    end

    context "when classes definition is empty or not valid XML" do
      before(:each) do
        allow(Yast::SCR).to receive(:Read).and_call_original
        allow(Yast::SCR).to receive(:Read).with(Yast::Path.new(".xml"), CLASS_PATH).and_return(nil)
        expect(Y2Autoinstallation::XmlChecks).to receive(:valid_classes?).and_return(false)
      end

      it "set Classes to []" do
        subject.Read
        expect(subject.Classes).to eq([])
      end

      it "returns nil" do
        expect(subject.Read).to be_nil
      end
    end
  end

  describe "#Files" do
    before(:each) do
      subject.Read
    end

    context "when some class definition exists" do
      it "sets confs to an array containing classes configurations" do
        subject.Files
        expect(subject.confs).to match_array(
          [
            { "class" => "swap", "name" => "largeswap.xml" },
            { "class" => "swap", "name" => "largeswap_noroot.xml" }
          ]
        )
      end
    end

    context "when classes definitions are not found" do
      let(:swap_class_dir) { File.join(CLASS_DIR, "swap") }

      before(:each) do
        allow(Yast::SCR).to receive(:Read)
          .with(Yast::Path.new(".target.dir"), swap_class_dir).and_return(directory_content)
      end

      context "when directory does not exist" do
        let(:directory_content) { nil }

        it "sets confs to an empty array" do
          subject.Files
          expect(subject.confs).to be_kind_of(Array)
          expect(subject.confs).to be_empty
        end
      end

      context "when directory is empty" do
        let(:directory_content) { [] }

        it "sets confs to an empty array" do
          subject.Files
          expect(subject.confs).to be_kind_of(Array)
          expect(subject.confs).to be_empty
        end
      end
    end
  end

  describe "#classDirChanged" do
    let(:new_class_dir) { File.join(FIXTURES_PATH, "new_classes") }

    after(:each) do
      # Restore original configuration after the test
      allow(Yast::AutoinstConfig).to receive(:classDir=).with(CLASS_DIR).and_call_original
      allow(subject).to receive(:Read)
      subject.classDirChanged(CLASS_DIR)
    end

    it "reads again the classes definitions" do
      expect(Yast::AutoinstConfig).to receive(:classDir=).with(new_class_dir).and_call_original
      expect(subject).to receive(:Read)
      subject.classDirChanged(new_class_dir)
    end
  end

  describe "#findPath" do
    let(:_class) { "swap" }
    let(:name) { "largeswap.xml" }

    before(:each) do |_example|
      subject.Files
    end

    context "when class and configuration exists" do
      it "returns string with path to classes directory, class name and configuration" do
        expect(subject.findPath(name, _class)).to eq(File.join(CLASS_DIR, _class, name))
      end
    end

    context "when class does not exist" do
      let(:_class) { "not-existent-class" }

      it "returns string with path to a default directory below the classes directory" do
        expect(subject.findPath(name, _class)).to eq(File.join(CLASS_DIR, "default"))
      end
    end

    context "when name does not exist" do
      let(:name) { "not-existent-name" }

      it "returns string with path to a default directory below the classes directory" do
        expect(subject.findPath(name, _class)).to eq(File.join(CLASS_DIR, "default"))
      end
    end
  end

  describe "#Compat" do
    let(:faked_autoinstall_dir) { File.join(FIXTURES_PATH, "etc", "autoinstall") }

    around(:each) do |example|
      subject.ClassConf = faked_autoinstall_dir
      example.call
      subject.ClassConf = "/etc/autoinstall"
    end

    context "when a classes.xml file exists in the new location" do
      it "does not overwrite classes.xml file" do
        expect(Yast::XML).to_not receive(:YCPToXMLFile)
        subject.Compat
      end
    end

    context "when a classes.xml file does not exist in the new location" do
      before(:each) do
        allow(Yast::SCR).to receive(:Read).and_call_original
        allow(Yast::SCR).to receive(:Read)
          .with(Yast::Path.new(".target.size"), CLASS_PATH).and_return(-1)
      end

      context "and /etc/autoinstall/classes.xml exists" do
        it "creates a classes.xml file in the new location" do
          expect(Yast::XML).to receive(:YCPToXMLFile) do |type, data, path|
            expect(type).to eq(:class)
            expect(data["classes"]).to be_kind_of(Array)
            expect(path).to eq(File.join(CLASS_DIR, "classes.xml"))
          end
          subject.Compat
        end
      end

      context "and /etc/autoinstall/classes.xml is empty or not valid XML" do
        before(:each) do
          allow(Yast::SCR).to receive(:Read)
            .with(Yast::Path.new(".xml"), File.join(faked_autoinstall_dir, "classes.xml"))
            .and_return(nil)
        end

        it "creates a classes.xmlfile in the new location with no classes" do
          expect(Yast::XML).to receive(:YCPToXMLFile)
            .with(:class, { "classes" => [] }, File.join(CLASS_DIR, "classes.xml"))
          subject.Compat
        end
      end
    end
  end

  describe "#class_dir=" do
    it "sets the classes definitions directory" do
      subject.class_dir = FIXTURES_PATH
      expect(subject.classDir).to eq(FIXTURES_PATH)
    end
  end

  describe "#MergeClasses" do
    let(:base_profile_path) { File.join(FIXTURES_PATH, "profiles", "partitions.xml") }
    let(:tmp_dir) { File.join(ROOT_PATH, "tmp") }
    let(:expected_xml) { File.read(expected_xml_path) }
    let(:output_path) { File.join(tmp_dir, "output.xml") }
    let(:output_xml) { File.read(output_path) }
    let(:dontmerge) { [] }
    let(:merge_xslt_path) { File.join(ROOT_PATH, "xslt", "merge.xslt") }
    let(:conf_to_merge) { { "class" => "swap", "name" => "largeswap.xml" } }
    let(:xsltproc_command) do
      "/usr/bin/xsltproc --novalid --maxdepth 10000 --param replace \"'false'\"  " \
      "--param with \"'#{subject.findPath("largeswap.xml", "swap")}'\"  "\
      "--output #{File.join(tmp_dir, "output.xml")}  " \
      "#{merge_xslt_path} #{base_profile_path} "
    end

    before(:each) do
      stub_const("Yast::AutoinstClassClass::MERGE_XSLT_PATH", merge_xslt_path)
    end

    around(:each) do |example|
      FileUtils.rm_rf(tmp_dir) if Dir.exist?(tmp_dir)
      FileUtils.mkdir(tmp_dir)
      example.run
      FileUtils.rm_rf(tmp_dir)
    end

    before(:each) do
      allow(Yast::AutoinstConfig).to receive(:tmpDir).and_return(tmp_dir)
      allow(Yast::AutoinstConfig).to receive(:dontmerge).and_return(dontmerge)
      subject.Files
    end

    it "executes xsltproc and returns a hash with info about the result" do
      expect(Yast::SCR).to receive(:Execute)
        .with(Yast::Path.new(".target.bash_output"), xsltproc_command, {}).and_call_original
      out = subject.MergeClasses(conf_to_merge, base_profile_path, "output.xml")
      expect(out).to eq("exit" => 0, "stderr" => "", "stdout" => "")
    end

    context "when all elements must be merged" do
      let(:expected_xml_path) do
        File.join(ROOT_PATH, "test", "fixtures", "output", "partitions-merged.xml")
      end

      it "merges elements from profile and configuration" do
        expect(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash_output"), xsltproc_command, {}).and_call_original
        subject.MergeClasses(conf_to_merge, base_profile_path, "output.xml")
        expect(output_xml).to eq(expected_xml)
      end
    end

    context "when some elements are not intended to be merged" do
      let(:expected_xml_path) do
        File.join(ROOT_PATH, "test", "fixtures", "output", "partitions-dontmerge.xml")
      end
      let(:dontmerge) { ["partition"] }
      let(:xsltproc_command) do
        "/usr/bin/xsltproc --novalid --maxdepth 10000 --param replace \"'false'\"  " \
        "--param dontmerge1 \"'partition'\"  " \
        "--param with \"'#{subject.findPath("largeswap.xml", "swap")}'\"  "\
        "--output #{File.join(tmp_dir, "output.xml")}  " \
        "#{merge_xslt_path} #{base_profile_path} "
      end

      it "does not merge those elements" do
        expect(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash_output"), xsltproc_command, {}).and_call_original
        subject.MergeClasses(conf_to_merge, base_profile_path, "output.xml")
        expect(output_xml).to eq(expected_xml)
      end
    end
  end

  describe "#Import" do
    it "sets profile_conf variable as a copy of the given settings" do
      subject.Import(settings)
      expect(subject.profile_conf).to eq(settings)
      expect(subject.profile_conf).to_not equal(settings)
    end

    after(:each) do
      subject.Import([])
    end
  end

  describe "#Export" do
    around(:each) do |example|
      subject.Import(settings)
      example.call
      subject.Import([]) # reset settings
    end

    it "returns a copy of profile_conf" do
      exported = subject.Export
      expect(exported).to eq(settings)
      expect(exported).to_not equal(settings)
    end
  end

  describe "#Summary" do
    context "when some settings are given" do
      around(:each) do |example|
        subject.Import(settings)
        example.call
        subject.Import([]) # reset settings
      end

      it "returns a summary containing class names and configurations" do
        expect(Yast::Summary).to receive(:AddHeader).with(anything, "swap")
          .and_return("<h3>swap</h3>")
        expect(Yast::Summary).to receive(:AddLine).with(anything, "largeswap.xml")
          .and_return("<h3>swap</h3><p>largeswap.xml</p>")
        expect(subject.Summary).to eq("<h3>swap</h3><p>largeswap.xml</p>")
      end

      context "when no class name is given" do
        let(:settings) { [{ "configuration" => "largeswap.xml" }] }

        it "'None' is used instead" do
          expect(Yast::Summary).to receive(:AddHeader).with(anything, "None")
            .and_return("<h3>None</h3>")
          subject.Summary
        end
      end

      context "when no configuration is given" do
        let(:settings) { [{ "class_name" => "swap" }] }

        it "'None' is used instead" do
          expect(Yast::Summary).to receive(:AddLine).with(anything, "None")
            .and_return("<h3>None</h3><p>largeswap.xml</p>")
          subject.Summary
        end
      end
    end

    context "when no settings are given" do
      it "returns an empty summary" do
        expect(subject.Summary).to eq(Yast::Summary.NotConfigured)
      end
    end
  end

  describe "#Save" do
    before(:each) do
      subject.Read
    end

    it "creates a classes.xml file in the new location" do
      expect(Yast::XML).to receive(:YCPToXMLFile) do |type, data, path|
        expect(type).to eq(:class)
        expect(data["classes"]).to be_kind_of(Array)
        expect(path).to eq(File.join(CLASS_DIR, "classes.xml"))
      end
      subject.Save
    end

    it "does not raise exception when serialization failed" do
      subject.Classes = nil
      expect { subject.Save }.to_not raise_error
      subject.Classes = []
    end

    context "when classes are marked for deletion" do
      around(:each) do |example|
        subject.deletedClasses = ["swap"]
        example.call
        subject.deletedClasses = []
      end

      it "deletes classes files" do
        allow(Yast::XML).to receive(:YCPToXMLFile).with(any_args)
        expect(Yast::SCR).to receive(:Execute).with(
          Yast::Path.new(".target.bash"),
          "/bin/rm -rf #{CLASS_DIR}/swap"
        )

        subject.Save
      end
    end
  end
end
