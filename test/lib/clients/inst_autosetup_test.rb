# Copyright (c) [2020] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../../test_helper"
require "autoinstall/clients/inst_autosetup"

describe Y2Autoinstallation::Clients::InstAutosetup do
  describe "#main" do
    let(:product) do
      Y2Packager::Product.new(name: "SLES")
    end

    let(:cmdline) { "" }
    let(:s390_arch) { false }
    let(:profile_content) do
      {
        "bootloader" => { "boot" => "/dev/sda" },
        "software"   => { "packages" => ["yast2"] }
      }
    end
    let(:profile) { Yast::ProfileHash.new(profile_content) }

    let(:importer) { Y2Autoinstallation::Importer.new(profile) }

    before do
      allow(Yast::AutoinstGeneral).to receive(:Write)
      allow(Yast::AutoinstStorage).to receive(:Write)
      allow(Yast::AutoinstFunctions).to receive(:selected_product).and_return(product)
      allow(Yast::Progress).to receive(:Title)
      allow(Yast::AutoinstStorage).to receive(:Import).and_return(true)
      allow(Yast::AutoinstStorage).to receive(:Write).and_return(true)

      allow(Yast::WFM).to receive(:CallFunction).with(/_auto/, Array).and_return(true)
      allow(Yast::WFM).to receive(:CallFunction)
        .with("lan_auto", ["Packages"]).and_return("install" => [])
      allow(Yast::WFM).to receive(:ClientExists).with(/_auto/).and_return(true)
      allow(Yast::Popup).to receive(:ConfirmAbort).and_return(true)

      allow(Yast::SCR).to receive(:Read)
        .with(Yast::Path.new(".target.string"), "/proc/cmdline")
        .and_return(cmdline)
      allow(Yast::SCR).to receive(:Read).and_call_original

      allow(Yast::Arch).to receive(:s390).and_return(:s390_arch)
      allow(subject).to receive(:autosetup_network)
      allow(subject).to receive(:autosetup_country)
      allow(subject).to receive(:autosetup_security)
      allow(subject).to receive(:probe_storage)
      allow(Yast::AutoinstSoftware).to receive(:Write).and_return(true)
      allow(Yast::ServicesManager).to receive(:import)
      allow(Y2Autoinstallation::Importer).to receive(:new).and_return(importer)
      allow(importer).to receive(:import_entry).and_call_original
      allow(Yast::ProductControl).to receive(:RunFrom).and_return(:next)
      Yast::Profile.current = Yast::ProfileHash.new(profile)

      allow(Yast::Profile).to receive(:remove_sections)
    end

    it "sets up the network" do
      expect(subject).to receive(:autosetup_network)
      subject.main
    end

    it "sets up additional configuration files" do
      expect(importer).to receive(:import_entry).with("files")
        .and_return(Y2Autoinstallation::ImportResult.new(["files"], true))
      subject.main
    end

    context "when setting up additional configuration files fails" do
      before do
        allow(importer).to receive(:import_entry).with("files")
          .and_return(Y2Autoinstallation::ImportResult.new(["files"], false))
      end

      it "returns :abort" do
        expect(subject.main).to eq(:abort)
      end
    end

    it "sets up the country configuration" do
      expect(subject).to receive(:autosetup_country)
      subject.main
    end

    it "sets up the security settings" do
      expect(subject).to receive(:autosetup_security)
      subject.main
    end

    it "sets up the firewall configuration" do
      expect(subject).to receive(:autosetup_firewall)
      subject.main
    end

    it "sets up the partitioning schema" do
      expect(Yast::AutoinstStorage).to receive(:Import).and_return(true)
      expect(Yast::AutoinstStorage).to receive(:Write).and_return(true)
      subject.main
    end

    context "when partitioning fails" do
      before do
        allow(Yast::AutoinstStorage).to receive(:Write).and_return(false)
      end

      it "reports an error" do
        expect(Yast::Report).to receive(:Error).with(/configuring partitions/)
        subject.main
      end
    end

    it "sets up the bootloader configuration" do
      expect(Yast::WFM).to receive(:CallFunction)
        .with("bootloader_auto", ["Import", profile["bootloader"]])
      subject.main
    end

    context "when importing the bootloader configuration fails" do
      before do
        expect(Yast::WFM).to receive(:CallFunction)
          .with("bootloader_auto", Array).and_return(false)
      end

      it "returns :abort" do
        expect(subject.main).to eq(:abort)
      end
    end

    context "when configuration management settings are present in the profile" do
      let(:profile) do
        { "configuration_management" => { "master" => "salt.localdomain" } }
      end

      let(:import_result) { true }

      before do
        allow(Yast::WFM).to receive(:CallFunction).with("configuration_management_auto", Array)
          .and_return(import_result)
      end

      it "sets up the configuration management module" do
        expect(Yast::WFM).to receive(:CallFunction)
          .with("configuration_management_auto", ["Import", profile["configuration_management"]])
          .and_return(true)
        subject.main
      end

      it "removes the 'configuration_management' section from the profile" do
        expect(Yast::Profile).to receive(:remove_sections)
          .with("configuration_management")
        subject.main
      end

      context "when importing the settings fails" do
        let(:import_result) { false }

        it "returns :abort" do
          expect(subject.main).to eq(:abort)
        end
      end
    end

    context "when kdump settings are present in the profile" do
      let(:profile) do
        { "kdump" => { "enabled" => true } }
      end

      it "sets up the kdump module" do
        expect(Yast::WFM).to receive(:CallFunction)
          .with("kdump_auto", ["Import", Hash])
          .and_return(true)
        subject.main
      end

      it "removes the 'kdump' section from the profile" do
        expect(Yast::Profile).to receive(:remove_sections)
          .with("kdump")
        subject.main
      end
    end

    it "sets up the software" do
      expect(Yast::AutoinstSoftware).to receive(:Import).with(a_hash_including(profile["software"]))
      expect(Yast::AutoinstSoftware).to receive(:Write).and_return(true)
      subject.main
    end

    context "when processing the software configuration fails" do
      before do
        allow(Yast::AutoinstSoftware).to receive(:Write).and_return(false)
      end

      it "reports and error and returns :abort" do
        expect(Yast::Report).to receive(:Error).with(/software/)
        expect(subject.main).to eq(:abort)
      end
    end

    it "sets up the users" do
      expect(importer).to receive(:import_entry).with("users")
        .and_return(Y2Autoinstallation::ImportResult.new(["users"], true))
      subject.main
    end

    context "when setting up users fails" do
      before do
        allow(importer).to receive(:import_entry).with("users")
          .and_return(Y2Autoinstallation::ImportResult.new(["users"], false))
      end

      it "returns :abort" do
        expect(subject.main).to eq(:abort)
      end
    end

    context "when ssh import settings are present in the profile" do
      let(:profile) do
        { "ssh_import" => { "import" => true } }
      end

      let(:import_result) { true }

      before do
        allow(Yast::WFM).to receive(:CallFunction).with("ssh_import_auto", any_args)
          .and_return(import_result)
      end

      it "sets up the ssh import behavior" do
        expect(Yast::WFM).to receive(:CallFunction)
          .with("ssh_import_auto", ["Import", profile["ssh_import"]])
          .and_return(true)
        subject.main
      end

      it "removes the 'ssh_import' section from the profile" do
        expect(Yast::Profile).to receive(:remove_sections)
          .with("ssh_import")
        subject.main
      end

      context "when importing the settings fails" do
        let(:import_result) { false }

        it "returns :abort" do
          expect(subject.main).to eq(:abort)
        end
      end
    end

    context "when the user has to accept the base product license" do
      let(:profile) do
        { "general" => { "mode" => { "confirm_base_product_license" => true } } }
      end

      it "asks the user to accept the license" do
        expect(Yast::WFM).to receive(:CallFunction).with("inst_product_license", Array)
          .and_return(:next)
        subject.main
      end

      context "and does not accept the license" do
        before do
          allow(Yast::WFM).to receive(:CallFunction).with("inst_product_license", Array)
            .and_return(:abort)
        end

        it "returns :abort" do
          expect(subject.main).to eq(:abort)
        end
      end
    end

    context "when the add-on section is included" do
      let(:profile) do
        {
          "add-on" => {
            "add_on_products" => [
              { "media_url" => "relurl:///", "product_dir" => "/AddOn" }
            ]
          }
        }
      end

      it "removes the add-on section from the profile" do

        allow(Yast::Profile).to receive(:remove_sections).and_call_original
        expect(Yast::Profile.current).to have_key("add-on")
        expect(Yast::WFM).to receive(:CallFunction)
          .with("add-on_auto", ["Import", profile["add-on"]])
          .and_return(true)
        subject.main
        expect(Yast::Profile.current).to_not have_key("add-on")
      end
    end

    context "when the confirmation mode is not enabled" do
      before do
        allow(Yast::AutoinstConfig).to receive(:Confirm).and_return(false)
      end

      it "validates the security policy" do
        expect(subject).to receive(:autosetup_security_policy)
        subject.main
      end
    end

    context "when the confirmation mode is enabled" do
      before do
        allow(Yast::AutoinstConfig).to receive(:Confirm).and_return(true)
      end

      it "does not validate the security policy" do
        expect(subject).to_not receive(:autosetup_security_policy)
        subject.main
      end
    end
  end
end
