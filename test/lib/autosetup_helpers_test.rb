#!/usr/bin/env rspec
# Copyright (c) [2017] SUSE LLC
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

require_relative "../test_helper"
require "autoinstall/autosetup_helpers"

Yast.import "AutoinstConfig"
Yast.import "Profile"

describe Y2Autoinstallation::AutosetupHelpers do
  class DummyClient < Yast::Client
    include Yast::Logger
    include Y2Autoinstallation::AutosetupHelpers
  end

  subject(:client) { DummyClient.new }
  let(:profile_dir_path) { File.join(TESTS_PATH, "tmp") }

  describe "#probe_storage" do
    let(:storage_manager) { double(Y2Storage::StorageManager) }

    before do
      allow(Y2Storage::StorageManager).to receive(:instance).and_return(storage_manager)
    end

    it "activates and probes storage" do
      expect(storage_manager).to receive(:activate)
        .with(Y2Autoinstallation::ActivateCallbacks)
      expect(storage_manager).to receive(:probe)
      client.probe_storage
    end
  end

  describe "#suse_register" do
    let(:profile_content) { { "general" => {} } }
    let(:reg_module_available) { true }

    before do
      allow_any_instance_of(Y2Autoinstallation::AutosetupHelpers).to receive(
        :registration_module_available?
      ).and_return(reg_module_available)
      allow(Yast::Profile).to receive(:current).and_return(profile_content)
      allow(Yast::Profile).to receive(:remove_sections).with("suse_register")
    end

    context "yast2-register is not available" do
      let(:reg_module_available) { false }
      it "does not call any client and returns true." do
        # no scc_auto call at all
        expect(Yast::WFM).not_to receive(:CallFunction)
        expect(client.suse_register).to eq(true)
      end
    end

    context "yast2-register is available" do
      let(:reg_module_available) { true }

      context "suse_register tag is not defined in AY file" do
        it "does not call any client and returns true." do
          # no scc_auto call at all
          expect(Yast::WFM).not_to receive(:CallFunction)
          expect(client.suse_register).to eq(true)
        end
      end

      context "suse_register tag is defined in AY file" do
        let(:profile_content) { { "suse_register" => { "reg_code" => "12345" } } }

        before do
          allow(Yast::WFM).to receive(:CallFunction).with("inst_download_release_notes")
            .and_return(true)
          allow(Yast::WFM).to receive(:CallFunction).with("scc_auto", anything).and_return(true)
          Yast::Profile.Import(profile_content)
        end

        it "imports the registration settings from the profile" do
          expect(Yast::WFM).to receive(:CallFunction).with("scc_auto",
            ["Import", profile_content["suse_register"]]).and_return(true)
          expect(Yast::WFM).to receive(:CallFunction).with("scc_auto", ["Write"])
            .and_return(true)
          client.suse_register
        end

        it "downloads release notes" do
          expect(Yast::WFM).to receive(:CallFunction).with("inst_download_release_notes")
          client.suse_register
        end

        # bsc#1153293
        it "removes the registration section to not run it again in the 2nd stage" do
          expect(Yast::Profile).to receive(:remove_sections).with("suse_register")
          client.suse_register
        end

        it "returns true" do
          expect(client.suse_register).to eq(true)
        end

        context "when something goes wrong" do
          before do
            allow(Yast::WFM).to receive(:CallFunction).with("scc_auto", ["Write"]).and_return(false)
          end

          it "returns false" do
            expect(client.suse_register).to eq(false)
          end
        end
      end

      context "semi-automatic is defined in AY file" do
        let(:profile_content) { { "general" => { "semi-automatic" => ["scc"] } } }
        it "shows registration screen mask and returns true" do
          # Showing registration screen mask
          expect(Yast::WFM).to receive(:CallFunction).with("inst_scc",
            ["enable_next" => true])
          expect(client.suse_register).to eq(true)
        end
      end
    end
  end

  describe "#readModified" do
    let(:autoinst_profile_path) { File.join(profile_dir_path, "autoinst.xml") }
    let(:modified_profile_path) { File.join(profile_dir_path, "modified.xml") }
    let(:backup_profile_path) { File.join(profile_dir_path, "pre-autoinst.xml") }
    let(:profile_content) { { "general" => {} } }

    before do
      allow(Yast::AutoinstConfig).to receive(:profile_dir)
        .and_return(profile_dir_path)
      allow(Yast::AutoinstConfig).to receive(:modified_profile)
        .and_return(modified_profile_path)
    end

    around(:each) do |example|
      FileUtils.rm_rf(profile_dir_path) if Dir.exist?(profile_dir_path)
      FileUtils.mkdir(profile_dir_path)
      example.run
      FileUtils.rm_rf(profile_dir_path)
    end

    context "when modified profile exist" do
      before do
        File.write(modified_profile_path, "modified")
        File.write(autoinst_profile_path, "original")
        allow(Yast::Profile).to receive(:ReadXML).and_return(true)
        allow(Yast::Profile).to receive(:current).and_return(profile_content)
      end

      it "imports the modified one" do
        expect(Yast::Profile).to receive(:ReadXML).with(modified_profile_path)
          .and_return(true)
        client.readModified
      end

      it "backups up the original one" do
        client.readModified
        expect(File.read(backup_profile_path)).to eq("original")
      end

      it "replaces the original one" do
        client.readModified
        expect(File.read(autoinst_profile_path)).to eq("modified")
      end

      it "returns :found" do
        expect(client.readModified).to eq(:found)
      end

      it "sets modified_profile? to true" do
        client.readModified
        expect(client.modified_profile?).to eq(true)
      end

      context "and it cannot be read" do
        before do
          allow(Yast::Profile).to receive(:ReadXML).and_return(false)
        end

        it "returns :abort" do
          expect(client.readModified).to eq(:abort)
        end
      end

      context "and profile is empty" do
        let(:profile_content) { {} }

        it "returns :abort" do
          expect(client.readModified).to eq(:abort)
        end
      end
    end

    context "when modified profile does not exist" do
      it "returns :not_found" do
        expect(client.readModified).to eq(:not_found)
      end

      it "sets modified_profile? to false" do
        client.readModified
        expect(client.modified_profile?).to eq(false)
      end
    end

  end

  describe "#network_autosetup" do
    let(:profile) { networking_section }
    let(:networking_section) { { "networking" => { "setup_before_proposal" => true } } }
    let(:host_section) { { "host" => { "hosts" => [] } } }

    before do
      Yast::Profile.current = profile
      Yast::AutoinstConfig.main
      allow(Yast::WFM).to receive(:CallFunction).with("lan_auto", anything)
      allow(Yast::WFM).to receive(:CallFunction).with("inst_lan", anything)
      allow(Yast::WFM).to receive(:CallFunction).with("host_auto", anything)
    end

    context "when a networking section is defined in the profile" do
      it "imports the networking config" do
        expect(Yast::WFM)
          .to receive(:CallFunction)
          .with("lan_auto", ["Import", profile["networking"]])

        client.autosetup_network
      end

      it "removes the networking section from the profile" do
        client.autosetup_network
        expect(Yast::Profile.current.keys).to_not include("networking")
      end

      context "and the setup is defined to be run before the proposal" do
        let(:profile) { networking_section.merge(host_section) }
        let(:networking_section) { { "networking" => { "setup_before_proposal" => true } } }

        it "sets the network config to be written before the proposal" do
          expect { client.autosetup_network }
            .to change { Yast::AutoinstConfig.network_before_proposal }
            .from(false).to(true)
        end

        context "and a host section is defined" do
          it "imports the /etc/hosts config from the profile" do
            expect(Yast::WFM)
              .to receive(:CallFunction)
              .with("host_auto", ["Import", profile["host"]])

            client.autosetup_network
          end

          it "removes the host section from the profile" do
            client.autosetup_network
            expect(Yast::Profile.current.keys).to_not include("host")
          end
        end
      end
    end

    context "when the network configuration is semiautomatic" do
      let(:networking_section) { { "general" => { "semi-automatic" => ["networking"] } } }

      it "runs the network configuration client" do
        expect(Yast::WFM).to receive(:CallFunction).with("inst_lan", anything)

        client.autosetup_network
      end

      it "sets the network config to be written before the proposal" do
        expect { client.autosetup_network }
          .to change { Yast::AutoinstConfig.network_before_proposal }
          .from(false).to(true)
      end
    end

    context "in case it was definitely se to be configured before the proposal" do
      it "writes the network configuration calling the auto client" do
        Yast::AutoinstConfig.network_before_proposal = true
        expect(Yast::WFM).to receive(:CallFunction).with("lan_auto", ["Write"])

        client.autosetup_network
      end
    end
  end

  describe "#general_section" do
    let(:profile) { general_section }
    let(:general_section) { { "general" => { "semi-automatic" => ["networking"] } } }
    let(:register_section) { { "suse_register" => { "reg_code" => "12345" } } }

    before do
      Yast::Profile.current = profile
    end

    context "when the profile contains the general section" do
      it "returns it" do
        expect(client.general_section).to eql(general_section["general"])
      end
    end

    context "when the profile does not contain the general section" do
      let(:profile) { register_section }
      it "returns and empty hash" do
        expect(client.general_section).to eql({})
      end
    end
  end

  describe "#semi_auto?" do
    let(:profile) { general_section }
    let(:general_section) { { "general" => { "semi-automatic" => ["networking"] } } }

    before do
      Yast::Profile.current = profile
    end

    context "given a module name" do
      it "returns true if the module is part ot the profile semi-automatic list" do
        expect(client.semi_auto?("networking")).to eql(true)
      end

      it "returns false otherwise" do
        expect(client.semi_auto?("partitioning")).to eql(false)
      end
    end
  end
end
