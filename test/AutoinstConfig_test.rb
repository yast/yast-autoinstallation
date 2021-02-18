#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "AutoinstConfig"

describe "Yast::AutoinstConfig" do

  subject { Yast::AutoinstConfig }

  describe "#find_slp_autoyast" do
    before do
      allow(Yast::SLP).to receive(:FindSrvs).with("autoyast", "").and_return(slp_server_reply)
    end

    context "when no 'autoyast' provider returned by SLP" do
      let(:slp_server_reply) { [] }

      it "returns nil" do
        expect(Yast::Report).to receive(:Error)
        expect(subject.find_slp_autoyast).to eq(nil)
      end
    end

    context "when only one 'autoyast' provider returned by SLP" do
      let(:service_url) { "https://192.168.0.1/autoinst.xml" }
      let(:slp_server_reply) { [{ "srvurl" => "service:autoyast:#{service_url}" }] }

      it "returns the service URL" do
        expect(subject.find_slp_autoyast).to eq(service_url)
      end
    end

    context "when two or more 'autoyast' services are returned by SLP" do
      before do
        allow(Yast::UI).to receive(:OpenDialog).and_return(true)
        allow(Yast::UI).to receive(:UserInput).and_return(:ok)
        allow(Yast::UI).to receive(:CloseDialog).and_return(true)
        expect(Yast::UI).to receive(:QueryWidget).and_return(service_url_2)
      end

      let(:service_url_1) { "https://192.168.0.1/autoinst.xml" }
      let(:service_url_2) { "https://192.168.0.2/autoinst.xml" }

      let(:slp_server_reply) do
        [
          { "srvurl" => "service:autoyast:#{service_url_1}" },
          { "srvurl" => "service:autoyast:#{service_url_2}" }
        ]
      end

      context "when no additional SLP attributes are found" do
        it "asks user to choose one URL and returns the selected one" do
          allow(Yast::SLP).to receive(:FindAttrs).and_return([])

          expect(subject.find_slp_autoyast).to eq(service_url_2)
        end
      end
    end
  end

  describe "#update_profile_location" do
    context "when profile location is not defined" do
      it "returns 'floppy' with path to a profile as the new location" do
        expect(subject.update_profile_location("")).to match(/floppy:\/+.*xml/)
      end
    end

    context "when profile location is 'default'" do
      it "returns 'file' with path to a profile as the new location" do
        expect(subject.update_profile_location("default")).to match(/file:\/+.*xml/)
      end
    end

    context "when profile location is 'usb'" do
      it "returns 'usb' with path to a profile as the new location" do
        expect(subject.update_profile_location("usb")).to match(/usb:\/+.*xml/)
      end
    end

    context "when profile location is 'slp'" do
      let(:url_from_slp) { "https://user@pass:server/path/to/profile.xml" }

      it "returns the URL found using SLP search" do
        allow(subject).to receive(:find_slp_autoyast).and_return(url_from_slp)
        expect(subject.update_profile_location("slp")).to eq(url_from_slp)
      end
    end
  end

  describe "#ParseCmdLine" do
    context "when the profile url is invalid" do
      let(:autoyast_profile_url) { "//file:8080/path/auto-installation.xml" }
      it "reports an error and returns false" do
        expect(Yast::Report).to receive(:Error).with(/Invalid.*/)
        expect(subject.ParseCmdLine(autoyast_profile_url)).to eq(false)
      end
    end

    context "when the autoyast profile url is valid" do
      let(:autoyast_profile_url) { "https://moo:woo@192.168.0.1:8080/path/auto-installation.xml" }

      it "parses the given profile location and fill internal structures " \
          "and returns boolean whether it succeded" do
        expect(subject.ParseCmdLine(autoyast_profile_url)).to eq(true)

        expect(subject.scheme).to eq("https")
        expect(subject.host).to eq("192.168.0.1")
        expect(subject.filepath).to eq("/path/auto-installation.xml")
        expect(subject.port).to eq("8080")
        expect(subject.user).to eq("moo")
        expect(subject.pass).to eq("woo")
      end
    end

    context "when \"relurl\" is defined" do
      let(:autoyast_profile_url) { "relurl://auto-installation.xml" }
      it "sets host and filename correctly" do
        expect(subject.ParseCmdLine(autoyast_profile_url)).to eq(true)
        expect(subject.host).to eq("")
        expect(subject.scheme).to eq("relurl")
        expect(subject.filepath).to eq("auto-installation.xml")
      end
    end

    context "when \"relurl\" is defined and sub-pathes are defined" do
      let(:autoyast_profile_url) { "relurl://sub_path/auto-installation.xml" }
      it "sets host and filename correctly" do
        expect(subject.ParseCmdLine(autoyast_profile_url)).to eq(true)
        expect(subject.host).to eq("")
        expect(subject.scheme).to eq("relurl")
        expect(subject.filepath).to eq("sub_path/auto-installation.xml")
      end
    end

    context "when \"file:\/\/\" is defined" do
      context "when no sub path is defined" do
        let(:autoyast_profile_url) { "file://auto-installation.xml" }
        it "sets host and filename correctly" do
          expect(subject.ParseCmdLine(autoyast_profile_url)).to eq(true)
          expect(subject.host).to eq("")
          expect(subject.scheme).to eq("file")
          expect(subject.filepath).to eq("auto-installation.xml")
        end
      end

      context "when sub path is defined" do
        let(:autoyast_profile_url) { "file://sub-path/auto-installation.xml" }
        it "sets host and filename correctly" do
          expect(subject.ParseCmdLine(autoyast_profile_url)).to eq(true)
          expect(subject.host).to eq("")
          expect(subject.scheme).to eq("file")
          expect(subject.filepath).to eq("sub-path/auto-installation.xml")
        end
      end
    end

    context "when \"file:///\" is defined (old format)" do
      context "when no sub path is defined" do
        let(:autoyast_profile_url) { "file:///auto-installation.xml" }
        it "sets host and filename correctly" do
          expect(subject.ParseCmdLine(autoyast_profile_url)).to eq(true)
          expect(subject.host).to eq("")
          expect(subject.scheme).to eq("file")
          expect(subject.filepath).to eq("/auto-installation.xml")
        end
      end

      context "when sub path is defined" do
        let(:autoyast_profile_url) { "file:///sub-path/auto-installation.xml" }
        it "sets host and filename correctly" do
          expect(subject.ParseCmdLine(autoyast_profile_url)).to eq(true)
          expect(subject.host).to eq("")
          expect(subject.scheme).to eq("file")
          expect(subject.filepath).to eq("/sub-path/auto-installation.xml")
        end
      end
    end
  end

  describe "#profile_path" do
    it "returns '/<profile_path>/autoinst.xml'" do
      expect(subject.profile_path).to eq("/tmp/profile/autoinst.xml")
    end
  end

  describe "#profile_backup_path" do
    it "returns '/<profile_path>/pre-autoinst.xml'" do
      expect(subject.profile_backup_path).to eq("/tmp/profile/pre-autoinst.xml")
    end
  end
end
