#!/usr/bin/env rspec
# encoding: utf-8

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
        :registration_module_available?).and_return(reg_module_available)
      allow(Yast::Profile).to receive(:current).and_return(profile_content)
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
          allow(Yast::WFM).to receive(:CallFunction).with("inst_download_release_notes").and_return(true)
          allow(Yast::WFM).to receive(:CallFunction).with("scc_auto", anything).and_return(true)
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
        let(:profile_content) { { "general" => {"semi-automatic" => ["scc"]} } }
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
end
