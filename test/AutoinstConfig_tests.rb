#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "AutoinstConfig"
Yast.import "Profile"

describe "Yast::AutoinstConfig" do

  subject { Yast::AutoinstConfig }

  describe "#find_slp_autoyast" do
    before do
      allow(Yast::SLP).to receive(:FindSrvs).with("autoyast", "").and_return(slp_server_reply)
    end

    context "when no 'autoyast' provider returned by SLP" do
      let(:slp_server_reply) { [] }

      it "returns nil" do
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

      let(:slp_server_reply) {
        [
          {"srvurl" => "service:autoyast:#{service_url_1}" },
          {"srvurl" => "service:autoyast:#{service_url_2}" }
        ]
      }

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
        expect(Yast::Report).to receive(:Error).with(/Invalid.*/).and_call_original
        expect(subject.ParseCmdLine(autoyast_profile_url)).to eq(false)
      end
    end

    context "when the autoyast profile url is valid" do
      let(:autoyast_profile_url) { "https://moo:woo@192.168.0.1:8080/path/auto-installation.xml" }

      it "parses the given profile location and fill internal structures and returns boolean whether it succeded" do
        expect(subject.ParseCmdLine(autoyast_profile_url)).to eq(true)

        expect(subject.scheme).to eq("https")
        expect(subject.host).to eq("192.168.0.1")
        expect(subject.filepath).to eq("/path/auto-installation.xml")
        expect(subject.port).to eq("8080")
        expect(subject.user).to eq("moo")
        expect(subject.pass).to eq("woo")
      end
    end
  end

  describe "#selected_product" do
    def base_product(name, short_name)
      Y2Packager::Product.new(name: name, short_name: short_name)
    end

    let(:selected_name) { "SLES15" }

    before(:each) do
      allow(Y2Packager::Product)
        .to receive(:available_base_products)
        .and_return(
          [
            base_product("SLES", selected_name),
            base_product("SLED", "SLED15")
          ]
        )

        # reset cache between tests
        subject.instance_variable_set(:@selected_product, nil)
    end

    it "returns proper base product when explicitly selected in the profile and such base product exists on media" do
      allow(Yast::Profile)
        .to receive(:current)
        .and_return("software" => { "products" => [selected_name] })

      expect(subject.selected_product.short_name).to eql selected_name
    end

    it "returns nil when product is explicitly selected in the profile and such base product doesn't exist on media" do
      allow(Yast::Profile)
        .to receive(:current)
        .and_return("software" => { "products" => { "product" => "Fedora" } })

      expect(subject.selected_product).to be nil
    end

    it "returns base product identified by patterns in the profile if such base product exists on media" do
      allow(Yast::Profile)
        .to receive(:current)
        .and_return("software" => { "patterns" => ["sles-base-32bit"] })

      expect(subject.selected_product.short_name).to eql selected_name
    end

    it "returns base product identified by packages in the profile if such base product exists on media" do
      allow(Yast::Profile)
        .to receive(:current)
        .and_return("software" => { "packages" => ["sles-release"] })

      expect(subject.selected_product.short_name).to eql selected_name
    end

    it "returns base product if there is just one on media and product cannot be identified from profile" do
      allow(Y2Packager::Product)
        .to receive(:available_base_products)
        .and_return(
          [
            base_product("SLED", "SLED15")
          ]
        )
      allow(Yast::Profile)
        .to receive(:current)
        .and_return("software" => {})

      expect(subject.selected_product.short_name).to eql "SLED15"
    end
  end
end
