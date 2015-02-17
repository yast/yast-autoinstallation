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

    it 'returns classes directory + class name + configuration' do
      subject.Read
      subject.Files
      expect(subject.findPath(name, _class)).to eq(File.join(class_dir, _class, name))
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

  describe '#class_file_exists?' do
    context 'when a classes.xml exists in the repository' do
      it 'returns true' do
        expect(subject.class_file_exists?).to eq(true)
      end
    end

    context 'when classes.xml does not exist in the repository' do
      let(:class_dir) { test_xml_dir }

      it 'returns false' do
        expect(subject.class_file_exists?).to be_false
      end
    end
  end

  describe '#compat_class_file_exists?' do
    after(:each) do
      subject.ClassConf = '/etc/autoinstall'
    end

    context 'when /etc/autoinstall/classes.xml exists' do
      before(:each) do
        subject.ClassConf = faked_autoinstall_dir
      end

      it 'returns true' do
        expect(subject.compat_class_file_exists?).to be_true
      end
    end

    context 'when /etc/autoinstall/classes.xml does not exist' do
      before(:each) do
        subject.ClassConf = File.join(test_xml_dir, '..')
      end

      it 'returns false' do
        expect(subject.compat_class_file_exists?).to be_false
      end
    end
  end

  describe '#read_old_classes' do
    around(:each) do |example|
      subject.ClassConf = faked_autoinstall_dir
      example.call
      subject.ClassConf = '/etc/autoinstall'
    end

    it 'returns an array containig the classes' do
      expect(subject.read_old_classes).to eq(
        [{"configuration" => "largeswap.xml", "name" => "swap"}]
      )
    end
  end

  describe '#changeDir' do
    it 'sets the classes directory' do
      subject.class_dir = test_xml_dir
      expect(subject.classDir).to eq(test_xml_dir)
    end
  end
end
