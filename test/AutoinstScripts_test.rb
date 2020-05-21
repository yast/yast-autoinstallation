#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "AutoinstScripts"

describe "Yast::AutoinstScripts" do
  subject { Yast::AutoinstScripts }

  before do
    allow(Yast::Mode).to receive(:autoinst).and_return true
    # re-init
    subject.main
  end

  describe "#GetModified" do
    it "returns false if modified flag is not set" do
      expect(subject.GetModified).to eq false
    end

    it "returns true if modified flag is set" do
      subject.SetModified
      expect(subject.GetModified).to eq true
    end
  end

  describe "#SetModified" do
    it "sets modified flag" do
      expect { subject.SetModified }.to change { subject.GetModified }.from(false).to(true)
    end
  end

  describe "#Import" do
    shared_examples "resolve location" do
      # this examples expect to have defined type and key
      it "strip white spaces from location" do
        data = { key => [
          { "location" => "https://test.com/script  \n \t   " },
          { "location" => "\n\t  https://test.com/script2" }
        ] }
        expected = [
          "https://test.com/script",
          "https://test.com/script2"
        ]

        subject.Import(data)
        expect(subject.public_send(type).map(&:location)).to eq expected
      end

      context "autoyast profile url is not relurl schema" do
        before do
          Yast::AutoinstConfig.ParseCmdLine("https://example.com/profile.xml")
        end

        it "resolve relurl using autoyast profile url" do
          data = { key => [
            { "location" => "https://test.com/script" },
            { "location" => "relurl://script2" }
          ] }
          expected = [
            "https://test.com/script",
            "https://example.com/script2"
          ]

          subject.Import(data)
          expect(subject.public_send(type).map(&:location)).to eq expected
        end
      end

      context "autoyast profile url is relurl schema" do
        before do
          Yast::AutoinstConfig.ParseCmdLine("relurl://profile.xml")
          allow(Yast::SCR).to receive(:Read).with(path(".etc.install_inf.ayrelurl"))
            .and_return("https://example2.com/ay/profile.xml")
        end

        it "resolve relurl using ayrelurl from install.inf" do
          data = { key => [
            { "location" => "https://test.com/script" },
            { "location" => "relurl://script2" }
          ] }
          expected = [ "https://test.com/script", "https://example2.com/ay/script2"]

          subject.Import(data)
          expect(subject.public_send(type).map(&:location)).to eq expected
        end
      end
    end

    context "pre-scripts" do
      let(:type) { :pre_scripts }
      let(:key) { "pre-scripts" }
      include_examples "resolve location"
    end

    context "init-scripts" do
      let(:type) { :init_scripts }
      let(:key) { "init-scripts" }
      include_examples "resolve location"
    end

    context "post-scripts" do
      let(:type) { :post_scripts }
      let(:key) { "post-scripts" }
      include_examples "resolve location"
    end

    context "chroot-scripts" do
      let(:type) { :chroot_scripts }
      let(:key) { "chroot-scripts" }
      include_examples "resolve location"
    end

    context "postpartitioning-scripts" do
      let(:type) { :postpart_scripts }
      let(:key) { "postpartitioning-scripts" }
      include_examples "resolve location"
    end
  end

  describe "#Export" do
    it "returns hash with defined scripts" do
      data = {
        "pre-scripts" => [{ "location" => "http://test.com/new_script", "param-list" => [],
            "filename" => "script4", "source" => "", "interpreter" => "perl", "rerun" => false,
            "debug" => false, "feedback" => false, "feedback_type" => "", "notification" => "" }]
      }

      subject.Import(data)
      expect(subject.Export).to eq data
    end
  end

  describe "#Summary" do
    it "returns richtext string with scripts summary" do
      data = {
        "pre-scripts"  => [{ "location" => "http://test.com/script" }],
        "post-scripts" => [{ "location" => "http://test.com/script2" },
                           { "location" => "http://test.com/script3" }]
      }

      subject.Import(data)
      expect(subject.Summary).to be_a(::String)
    end
  end

  describe "#AddEditScript" do
    context "given filename exists" do
      it "edits existing one" do
        data = {
          "pre-scripts"  => [{ "location" => "http://test.com/script", "filename" => "script1" }],
          "post-scripts" => [{ "location" => "http://test.com/script2", "filename" => "script2" },
                             { "location" => "http://test.com/script3", "filename" => "script3" }]
        }

        subject.Import(data)

        expected = [
          { "type" => "pre-scripts", "location" => "http://test.com/script",
            "filename" => "script1" },
          { "type" => "post-scripts", "location" => "http://test.com/new_script",
            "filename" => "script2", "source" => "", "interpreter" => "perl", "chrooted" => false,
            "debug" => false, "feedback" => false, "feedback_type" => "", "notification" => "" },
          { "type" => "post-scripts", "location" => "http://test.com/script3",
            "filename" => "script3" }
        ]

        subject.AddEditScript("script2", "", "perl", "post-scripts", false, false, false, "",
          "http://test.com/new_script", "")

        expect(subject.scripts.size).to eq 3
        new_script = subject.scripts.find { |s| s.filename == "script2" }
        expect(new_script.interpreter).to eq "perl"
        expect(new_script.source).to eq ""
        expect(new_script.location).to eq "http://test.com/new_script"
        expect(new_script).to be_a(Y2Autoinstallation::PostScript)
      end
    end

    context "given filename does not exist" do
      it "adds new one to merged" do
        data = {
          "pre-scripts"  => [{ "location" => "http://test.com/script", "filename" => "script1" }],
          "post-scripts" => [{ "location" => "http://test.com/script2", "filename" => "script2" },
                             { "location" => "http://test.com/script3", "filename" => "script3" }]
        }

        subject.Import(data)

        subject.AddEditScript("script4", "", "perl", "post-scripts", false, false, false,
          "", "http://test.com/new_script", "")

        expect(subject.scripts.size).to eq 4
        new_script = subject.scripts.find { |s| s.filename == "script4" }
        expect(new_script.interpreter).to eq "perl"
        expect(new_script.source).to eq ""
        expect(new_script.location).to eq "http://test.com/new_script"
        expect(new_script).to be_a(Y2Autoinstallation::PostScript)
      end
    end
  end

  describe "#deleteScript" do
    it "removes script with given filename from merged list" do
      data = {
        "pre-scripts"  => [{ "location" => "http://test.com/script", "filename" => "script1" }],
        "post-scripts" => [{ "location" => "http://test.com/script2", "filename" => "script2" },
                           { "location" => "http://test.com/script3", "filename" => "script3" }]
      }

      subject.Import(data)

      expect{subject.deleteScript("script2")}.to change{subject.scripts.size}.from(3).to(2)
    end
  end

  describe "#typeString" do
    it "returns string according to given type" do
      expect(subject.typeString("pre-scripts")).to eq "Pre"
    end

    it "returns localized \"Unknown\" for unknown type" do
      expect(subject.typeString("peklicko")).to eq "Unknown"
    end
  end

  describe "#Write" do
    before do
      # no real execution
      allow(Yast::SCR).to receive(:Execute)
    end

    it "returns true outside of auto installation and auto upgrade" do
      allow(Yast::Mode).to receive(:autoinst).and_return false
      allow(Yast::Mode).to receive(:autoupgrade).and_return false

      expect(subject.Write("pre-scripts", true)).to eq true
    end

    context "for pre-scripts" do
      it "downloads script from location if defined" do
        data = {
          "pre-scripts" => [{ "location" => "http://test.com/script", "filename" => "script1" }]
        }

        expect_any_instance_of(Yast::Transfer::FileFromUrl).to receive(:get_file_from_url) do |_klass, map|
          expect(map[:scheme]).to eq "http"
          expect(map[:host]).to eq "test.com"
          expect(map[:urlpath]).to eq "/script"
          expect(map[:localfile]).to match(/pre-scripts\/script1$/)

          true
        end

        subject.Import(data)
        subject.Write("pre-scripts", true)
      end

      it "creates script file from source if location not defined" do
        data = {
          "pre-scripts" => [{ "source"   => "echo krucifix > /home/dabel/body",
                              "filename" => "script1" }]
        }

        expect(Yast::SCR).to receive(:Write).with(path(".target.string"),
          /pre-scripts\/script1$/, "echo krucifix > /home/dabel/body")

        subject.Import(data)
        subject.Write("pre-scripts", true)
      end
    end

    context "for postpartitioning-scripts" do
      it "downloads script from location if defined" do
        data = {
          "postpartitioning-scripts" => [{ "location" => "http://test.com/script",
                                           "filename" => "script1" }]
        }

        expect_any_instance_of(Yast::Transfer::FileFromUrl).to receive(:get_file_from_url) do |_klass, map|
          expect(map[:scheme]).to eq "http"
          expect(map[:host]).to eq "test.com"
          expect(map[:urlpath]).to eq "/script"
          expect(map[:localfile]).to match(/postpartitioning-scripts\/script1$/)

          true
        end

        subject.Import(data)
        subject.Write("postpartitioning-scripts", true)
      end

      it "creates script file from source if location not defined" do
        data = {
          "postpartitioning-scripts" => [{ "source"   => "echo krucifix > /home/dabel/body",
                                           "filename" => "script1" }]
        }

        expect(Yast::SCR).to receive(:Write).with(path(".target.string"),
          /postpartitioning-scripts\/script1$/, "echo krucifix > /home/dabel/body")

        subject.Import(data)
        subject.Write("postpartitioning-scripts", true)
      end
    end

    context "for init-scripts" do
      it "downloads script from location if defined" do
        data = {
          "init-scripts" => [{ "location" => "http://test.com/script", "filename" => "script1" }]
        }

        expect_any_instance_of(Yast::Transfer::FileFromUrl).to receive(:get_file_from_url) do |_klass, map|
          expect(map[:scheme]).to eq "http"
          expect(map[:host]).to eq "test.com"
          expect(map[:urlpath]).to eq "/script"
          expect(map[:localfile]).to eq "/var/adm/autoinstall/init.d/script1"

          true
        end

        subject.Import(data)
        subject.Write("init-scripts", true)
      end

      it "creates script file from source if location not defined" do
        data = {
          "init-scripts" => [{ "source"   => "echo krucifix > /home/dabel/body",
                               "filename" => "script1" }]
        }

        expect(Yast::SCR).to receive(:Write).with(path(".target.string"),
          "/var/adm/autoinstall/init.d/script1", "echo krucifix > /home/dabel/body")

        subject.Import(data)
        subject.Write("init-scripts", true)
      end
    end

    it "executes script" do
      data = {
        "pre-scripts" => [{ "location" => "http://test.com/script", "filename" => "script1",
        "interpreter" => "shell", "rerun" => true }]
      }

      expect(Yast::SCR).to receive(:Execute).with(path(".target.bash"), /\/bin\/sh/)

      subject.Import(data)
      subject.Write("pre-scripts", true)
    end

    it "shows a feedback during script when notification is set for script" do
      data = {
        "pre-scripts" => [{ "location" => "http://test.com/script", "filename" => "script1",
        "interpreter" => "shell", "rerun" => true, "notification" => "Script1!!!" }]
      }

      expect(Yast::Popup).to receive(:ShowFeedback).with("", "Script1!!!")
      expect(Yast::Popup).to receive(:ClearFeedback)

      subject.Import(data)
      subject.Write("pre-scripts", true)
    end

    it "shows a report if feedback parameter is set" do
      data = {
        "pre-scripts" => [{ "location" => "http://test.com/script", "filename" => "script1",
        "interpreter" => "shell", "feedback" => true, "feedback_type" => "error", "rerun" => true }]
      }

      allow(Yast::SCR).to receive(:Read).and_return("test")
      expect(Yast::Report).to receive(:Error)

      subject.Import(data)
      subject.Write("pre-scripts", true)
    end
  end
end
