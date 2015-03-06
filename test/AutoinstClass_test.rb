#!/usr/bin/env rspec

root_path = File.expand_path('../..', __FILE__)
ENV["Y2DIR"] = File.join(root_path, 'src')

require "yast"

Yast.import "AutoinstClass"

describe Yast::AutoinstClass do
  subject { Yast::AutoinstClass }

  let(:test_xml_dir) { File.join(root_path, 'test', 'fixtures')  }
  let(:class_dir) { File.join(test_xml_dir, 'classes') }
  let(:class_path) { File.join(class_dir, 'classes.xml') }
  let(:faked_autoinstall_dir) { File.join(test_xml_dir, 'etc', 'autoinstall') }

  before(:each) do
    subject.class_dir = class_dir
  end

  describe '#Read' do
    context 'when some class definition exists' do
      it 'read content into @Classes' do
        subject.Read
        expect(subject.Classes).to_not be_empty
      end

      it 'returns nil' do
        expect(subject.Read).to be_nil
      end
    end

    context 'when classes definition file does not exist' do
      before(:each) do
        allow(Yast::SCR).to receive(:Read).with(Yast::Path.new('.target.size'), class_path).and_return(-1)
      end

      it 'sets Classes to []' do
        subject.Read
        expect(subject.Classes).to eq([])
      end

      it 'returns nil' do
        expect(subject.Read).to be_nil
      end
    end

    context 'when classes definition is empty or not valid XML' do
      before(:each) do
        allow(Yast::SCR).to receive(:Read).and_call_original
        allow(Yast::SCR).to receive(:Read).with(Yast::Path.new('.xml'), class_path).and_return(nil)
      end

      it 'set Classes to []' do
        subject.Read
        expect(subject.Classes).to eq([])
      end

      it 'returns nil' do
        expect(subject.Read).to be_nil
      end
    end
  end

  describe '#Files' do
    before(:each) do
      subject.Read
    end

    context 'when some class definition exists' do
      it 'sets confs to an array containing classes configurations' do
        subject.Files
        expect(subject.confs).to match_array([
          { "class" => "swap", "name" => "largeswap.xml" },
          { "class" => "swap", "name" => "largeswap_noroot.xml" }
        ])
      end
    end

    context 'when classes definitions are not found' do
      let(:swap_class_dir) { File.join(class_dir, 'swap') }

      before(:each) do
        allow(Yast::SCR).to receive(:Read).
          with(Yast::Path.new('.target.dir'), swap_class_dir).and_return(directory_content)
      end

      context 'when directory does not exist' do
        let(:directory_content) { nil }

        it 'sets confs to an empty array' do
          subject.Files
          expect(subject.confs).to be_kind_of(Array)
          expect(subject.confs).to be_empty
        end
      end

      context 'when directory is empty' do
        let(:directory_content) { [] }

        it 'sets confs to an empty array' do
          subject.Files
          expect(subject.confs).to be_kind_of(Array)
          expect(subject.confs).to be_empty
        end
      end
    end
  end

  describe '#classDirChanged' do
    let(:new_class_dir) { File.join(test_xml_dir, 'new_classes') }

    after(:each) do
      # Restore original configuration after the test
      allow(Yast::AutoinstConfig).to receive(:classDir=).with(class_dir).and_call_original
      allow(subject).to receive(:Read)
      subject.classDirChanged(class_dir)
    end

    it 'reads again the classes definitions' do
      expect(Yast::AutoinstConfig).to receive(:classDir=).with(new_class_dir).and_call_original
      expect(subject).to receive(:Read)
      subject.classDirChanged(new_class_dir)
    end
  end

  describe '#findPath' do
    let(:_class) { 'swap' }
    let(:name) { 'largeswap.xml' }

    before(:each) do |example|
      subject.Files
    end

    context 'when class and configuration exists' do
      it 'returns string with path to classes directory, class name and configuration' do
        expect(subject.findPath(name, _class)).to eq(File.join(class_dir, _class, name))
      end
    end

    context 'when class does not exist' do
      let(:_class) { 'not-existent-class' }

      it 'returns string with path to a default directory below the classes directory' do
        expect(subject.findPath(name, _class)).to eq(File.join(class_dir, 'default'))
      end
    end

    context 'when name does not exist' do
      let(:name) { 'not-existent-name' }

      it 'returns string with path to a default directory below the classes directory' do
        expect(subject.findPath(name, _class)).to eq(File.join(class_dir, 'default'))
      end
    end
  end

  describe '#Compat' do
    let(:faked_autoinstall_dir) { File.join(test_xml_dir, 'etc', 'autoinstall') }

    context 'when /etc/autoinstall/classes.xml exists' do
      around(:each) do |example|
        subject.ClassConf = faked_autoinstall_dir
        example.call
        subject.ClassConf = '/etc/autoinstall'
      end

      context 'and a classes.xml file does not exist in the new location' do
        before(:each) do
          allow(Yast::SCR).to receive(:Read).and_call_original
          allow(Yast::SCR).to receive(:Read).
            with(Yast::Path.new('.target.size'), class_path).and_return(-1)
        end

        it 'creates a classes.xml file in the new location' do
          expect(Yast::XML).to receive(:YCPToXMLFile) do |type, data, path|
            expect(type).to eq(:class)
            expect(data['classes']).to be_kind_of(Array)
            expect(path).to eq(File.join(class_dir, 'classes.xml'))
          end
          subject.Compat
        end
      end

      context 'and a classes.xml file exists in the new location' do
        it 'does not create a classes.xml file' do
          expect(Yast::XML).to_not receive(:YCPToXMLFile)
          subject.Compat
        end
      end
    end
  end

  describe '#class_dir=' do
    it 'sets the classes definitions directory' do
      subject.class_dir = test_xml_dir
      expect(subject.classDir).to eq(test_xml_dir)
    end
  end

  describe '#MergeClasses' do
    let(:base_profile_path) { File.join('test', 'fixtures', 'profiles', 'partitions.xml') }
    let(:tmp_dir) { File.join(root_path, 'tmp') }
    let(:expected_xml) { File.read(expected_xml_path) }
    let(:output_path) { File.join(tmp_dir, 'output.xml') }
    let(:output_xml) { File.read(output_path) }
    let(:dontmerge) { [] }
    let(:merge_xslt_path) { File.join('xslt', 'merge.xslt') }
    let(:xsltproc_command) {
      "/usr/bin/xsltproc --novalid --param replace \"'false'\"  " \
      "--param with \"'#{subject.findPath("largeswap.xml", "swap")}'\"  "\
      "--output #{File.join(tmp_dir, "output.xml")}  " \
      "#{merge_xslt_path} test/fixtures/profiles/partitions.xml "
    }

    around(:each) do |example|
      FileUtils.mkdir(tmp_dir) unless Dir.exist?(tmp_dir)
      old_merge_xslt_path = subject.merge_xslt_path
      subject.merge_xslt_path = merge_xslt_path
      example.run
      FileUtils.rm_rf(tmp_dir)
      subject.merge_xslt_path = old_merge_xslt_path
    end

    before(:each) do
      allow(Yast::AutoinstConfig).to receive(:tmpDir).and_return(tmp_dir)
      allow(Yast::AutoinstConfig).to receive(:dontmerge).and_return(dontmerge)
      subject.Files
    end

    it 'executes xsltproc and returns a hash with info about the result' do
      expect(Yast::SCR).to receive(:Execute).
        with(Yast::Path.new(".target.bash_output"), xsltproc_command, {}).and_call_original
      out = subject.MergeClasses(subject.confs[0], base_profile_path, 'output.xml')
      expect(out).to eq({ 'exit' => 0, 'stderr' => '', 'stdout' => '' })
    end

    context 'when all elements must be merged' do
      let(:expected_xml_path) { File.join(root_path, 'test', 'fixtures', 'output', 'partitions-merged.xml')  }

      it 'merges elements from profile and configuration' do
        expect(Yast::SCR).to receive(:Execute).
          with(Yast::Path.new(".target.bash_output"), xsltproc_command, {}).and_call_original
        subject.MergeClasses(subject.confs[0], base_profile_path, 'output.xml')
        expect(output_xml).to eq(expected_xml)
      end
    end

    context 'when some elements are not intended to be merged' do
      let(:expected_xml_path) { File.join(root_path, 'test', 'fixtures', 'output', 'partitions-dontmerge.xml')  }
      let(:dontmerge) { ['partition'] }
      let(:xsltproc_command) {
        "/usr/bin/xsltproc --novalid --param replace \"'false'\"  " \
        "--param dontmerge1 \"'partition'\"  " \
        "--param with \"'#{subject.findPath("largeswap.xml", "swap")}'\"  "\
        "--output #{File.join(tmp_dir, "output.xml")}  " \
        "#{merge_xslt_path} test/fixtures/profiles/partitions.xml "
      }

      it 'does not merge those elements' do
        expect(Yast::SCR).to receive(:Execute).
          with(Yast::Path.new(".target.bash_output"), xsltproc_command, {}).and_call_original
        subject.MergeClasses(subject.confs[0], base_profile_path, 'output.xml')
        expect(output_xml).to eq(expected_xml)
      end
    end
  end
end
