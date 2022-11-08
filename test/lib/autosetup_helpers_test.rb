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
require "y2security/security_policies/rule"

Yast.import "AutoinstConfig"
Yast.import "Profile"

describe Y2Autoinstallation::AutosetupHelpers do
  class DummyClient < Yast::Client
    include Yast::Logger
    include Y2Autoinstallation::AutosetupHelpers
  end

  subject(:client) { DummyClient.new }
  let(:profile_dir_path) { File.join(TESTS_PATH, "tmp") }

  before do
    allow(Y2Autoinstallation::XmlChecks.instance)
      .to receive(:valid_modified_profile?).and_return(true)
  end

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
    let(:profile_content) { Yast::ProfileHash.new("general" => {}) }
    let(:reg_module_available) { true }

    before do
      allow_any_instance_of(Y2Autoinstallation::AutosetupHelpers).to receive(
        :registration_module_available?
      ).and_return(reg_module_available)
      allow(Yast::Profile).to receive(:remove_sections).with("suse_register")
      Yast::Profile.Import(profile_content)
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
        context "and the registration is disabled explicitly" do
          let(:profile_content) { { "suse_register" => { "do_registration" => false } } }

          it "does not call any client and returns true." do
            # no scc_auto call at all
            expect(Yast::WFM).not_to receive(:CallFunction)
            expect(client.suse_register).to eq(true)
          end
        end

        context "and the registration is not disabled explicitly" do
          let(:profile_content) { { "suse_register" => { "reg_code" => "12345" } } }

          before do
            allow(Yast::WFM).to receive(:CallFunction).with("inst_download_release_notes")
              .and_return(true)
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
              allow(Yast::WFM).to receive(:CallFunction).with("scc_auto", ["Write"])
                .and_return(false)
            end

            it "returns false" do
              expect(client.suse_register).to eq(false)
            end
          end
        end
      end

      context "semi-automatic is defined in AY file" do
        let(:profile_content) do
          Yast::ProfileHash.new("general" => { "semi-automatic" => ["scc"] })
        end

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

      context "when the modified profile is not valid" do
        before do
          expect(Y2Autoinstallation::XmlChecks.instance).to receive(:valid_modified_profile?)
            .and_return(false)
        end

        it "returns :abort" do
          expect(client.readModified).to eq(:abort)
        end

        it "sets modified_profile? to false" do
          client.readModified
          expect(client.modified_profile?).to eq(false)
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

  describe "#autosetup_firewall" do
    let(:profile) { Yast::ProfileHash.new("firewall" => firewall_section) }
    let(:firewall_section) { { "default_zone" => "external" } }

    before(:each) do
      Yast::Profile.current = profile
      Yast::AutoinstConfig.main

      allow(Yast::WFM).to receive(:CallFunction).with("firewall_auto", anything)
    end

    context "when a firewall section is present in the profile" do
      context "when no second stage run is needed" do
        before(:each) do
          allow(client).to receive(:need_second_stage_run?).and_return(false)
        end

        it "removes the firewall section from the profile" do
          client.autosetup_firewall
          expect(Yast::Profile.current.keys).to_not include("firewall")
        end
      end

      context "when second stage run is needed" do
        before(:each) do
          allow(client).to receive(:need_second_stage_run?).and_return(true)
        end

        it "does not remove the firewall section from the profile" do
          client.autosetup_firewall
          expect(Yast::Profile.current.keys).to include("firewall")
        end

        it "does not corrupt the profile" do
          client.autosetup_firewall
          expect(Yast::Profile.current).to eql profile
        end
      end
    end
  end

  describe "#autosetup_network" do
    let(:profile) { Yast::ProfileHash.new(networking_section) }
    let(:networking_section) { { "networking" => { "setup_before_proposal" => true } } }
    let(:host_section) { { "host" => { "hosts" => [] } } }

    before do
      Yast::Profile.current = profile
      Yast::AutoinstConfig.main
      allow(Yast::WFM).to receive(:CallFunction).with("lan_auto", anything)
      allow(Yast::WFM).to receive(:CallFunction).with("inst_lan", anything)
      allow(Yast::WFM).to receive(:CallFunction).with("host_auto", anything)
      allow(Yast::WFM).to receive(:CallFunction).with("proxy_auto", anything)
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
        let(:profile) { Yast::ProfileHash.new(networking_section.merge(host_section)) }
        let(:networking_section) { { "networking" => { "setup_before_proposal" => true } } }

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
        expect(Yast::WFM).to receive(:CallFunction)
          .with("inst_lan", ["enable_next" => true, "skip_detection" => true])

        client.autosetup_network
      end

      it "sets the network config to be written before the proposal" do
        allow(Yast::WFM).to receive(:CallFunction).with("inst_lan", anything)
        expect(Yast::WFM).to receive(:CallFunction).with("lan_auto", ["Write"])

        client.autosetup_network
      end
    end

    context "in case it was definitely set to be configured before the proposal" do
      let(:networking_section) do
        { "networking" => { "setup_before_proposal" => true } }
      end

      it "writes the network configuration calling the auto client" do
        expect(Yast::WFM).to receive(:CallFunction).with("lan_auto", ["Write"])

        client.autosetup_network
      end
    end

    context "when no network configuration is given" do
      let(:networking_section) { {} }

      it "imports the empty profile" do
        expect(Yast::WFM).to receive(:CallFunction).with("lan_auto", ["Import", {}])

        client.autosetup_network
      end
    end

    context "when proxy configuration is given" do
      let(:proxy_section) { { "enabled" => true, "http_proxy" => "http://proxy:3128" } }
      let(:profile) { Yast::ProfileHash.new("proxy" => proxy_section) }

      it "imports the proxy configuration from the profile" do
        expect(Yast::WFM).to receive(:CallFunction).with("proxy_auto", ["Import", proxy_section])

        client.autosetup_network
      end

      it "removes the host section from the profile after imported" do
        client.autosetup_network

        expect(Yast::Profile.current.keys).to_not include("proxy")
      end

      context "and the networking is configured to setup before the proposal" do
        let(:profile) do
          Yast::ProfileHash.new(networking_section.merge("proxy" => proxy_section))
        end

        it "writes the proxy configuration to the ins-sys" do
          expect(Yast::WFM).to receive(:CallFunction).with("proxy_auto", ["Write"])

          client.autosetup_network
        end
      end
    end
  end

  describe "#semi_auto?" do
    let(:profile) { Yast::ProfileHash.new(general_section) }
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

  describe "#autosetup_country" do
    let(:profile) do
      Yast::ProfileHash.new(language_section.merge(timezone_section).merge(keyboard_section))
    end
    let(:language_section) { { "language" => { "language" => "de_DE", "languages" => "es_ES" } } }
    let(:timezone_section) { {} }
    let(:keyboard_section) { {} }
    let(:use_english) { false }
    let(:language) { double("Yast::Language", Import: true, SwitchToEnglishIfNeeded: use_english) }

    before do
      Yast::Profile.current = profile
      allow(Yast::Installation).to receive(:encoding=)
      allow(Yast::Profile).to receive(:remove_sections)
    end

    it "sets the language config based on the profile" do
      expect(Yast::Language).to receive(:Import).with(language_section["language"])
      client.autosetup_country
    end

    it "sets the installation console font" do
      expect(Yast::Installation).to receive(:encoding=).with("UTF-8")
      client.autosetup_country
    end

    context "when the timezone section is declared" do
      let(:timezone_section) { { "timezone" => { "timezone" => "Europe/Berlin" } } }

      it "imports the timezone configuration" do
        expect(Yast::Timezone).to receive(:Import).with(timezone_section["timezone"])
        client.autosetup_country
      end

      it "removes the timezone section from the profile" do
        expect(Yast::Profile).to receive(:remove_sections).with("timezone")
        client.autosetup_country
      end
    end

    context "when the keyboard section is declared" do
      let(:keyboard_section) { { "keyboard" => { "mapping" => "spanish" } } }

      it "imports the keyboard configuration" do
        expect(Yast::Keyboard).to receive(:Import).with(keyboard_section["keyboard"], :keyboard)
        client.autosetup_country
      end

      it "removes the keyboard section" do
        expect(Yast::Profile).to receive(:remove_sections).with("keyboard")
        client.autosetup_country
      end
    end

    context "when the keyboard section is not declared" do
      context "but the language section is" do
        it "imports the language section from the keyboard module to infer the keyboard mapping" do
          expect(Yast::Keyboard).to receive(:Import).with(language_section["language"], :language)
          client.autosetup_country
        end
      end
    end

    context "when the language section is declared" do
      it "removes the section when all country settings have been already imported" do
        expect(Yast::Profile).to receive(:remove_sections).with("language")
        client.autosetup_country
      end
    end
  end

  describe "#autosetup_security_policy" do
    let(:target_config) do
      instance_double(Y2Security::SecurityPolicies::TargetConfig)
    end
    let(:policy) do
      instance_double(Y2Security::SecurityPolicies::Policy, name: "DISA STIG")
    end
    let(:failing_rules) { [] }

    before do
      allow(Y2Security::SecurityPolicies::Manager.instance)
        .to receive(:enabled_policy).and_return(policy)
      allow(Y2Security::SecurityPolicies::Manager.instance)
        .to receive(:failing_rules).and_return(failing_rules)
      allow(Y2Security::SecurityPolicies::TargetConfig)
        .to receive(:new).and_return(target_config)
    end

    context "when there are no issues" do
      it "does not report any issue" do
        expect(Yast::Report).to_not receive(:LongWarning)
          .with(/Dummy rule/)
        client.autosetup_security_policy
      end
    end

    context "when there are issues" do
      let(:rule) do
        instance_double(Y2Security::SecurityPolicies::Rule, id: "testing",
          description: "Dummy rule", identifiers: ["CCE-12345"], references: ["SLES-15-12345"])
      end
      let(:failing_rules) { [rule] }

      it "reports railing rules" do
        expect(Yast::Report).to receive(:LongWarning)
          .with(/DISA STIG.*Dummy rule \(CCE-12345, SLES-15-12345\)/)
        client.autosetup_security_policy
      end
    end
  end
end
