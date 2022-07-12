#!/usr/bin/env rspec
# Copyright (c) [2019] SUSE LLC
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
require "autoinstall/clients/inst_autoinit"

describe Y2Autoinstallation::Clients::InstAutoinit do
  let(:repo?) { true }
  let(:do_registration) { true }
  let(:setup_before_proposal) { false }

  let(:profile) do
    Yast::ProfileHash.new(
      "suse_register" => { "do_registration" => do_registration },
      "networking"    => { "setup_before_proposal" => setup_before_proposal }
    )
  end

  before do
    allow(Yast::UI).to receive(:UserInput).and_return(:next)
    allow(Yast::WFM).to receive(:CallFunction).and_return(true)
    # can easily ends up in endless loop
    allow(subject).to receive(:ProfileSourceDialog).and_return("")
    allow(subject).to receive(:autoinit_scripts).and_return(:ok)
    allow(Yast::Linuxrc).to receive(:useiscsi).and_return(false)
    allow(Yast::Linuxrc).to receive(:InstallInf).and_return(nil)
    allow(Yast::ProfileLocation).to receive(:Process).and_return(true)
    allow(Yast::Profile).to receive(:ReadXML).and_return(true)
    allow(Yast::Profile).to receive(:current).and_return(profile)
    allow(Yast::Mode).to receive(:autoupgrade).and_return(false)
    allow(Yast::AutoinstFunctions).to receive(:available_base_products).and_return([])
    allow(Y2Packager::InstallationMedium).to receive(:contain_multi_repos?).and_return(false)
    allow(Y2Packager::InstallationMedium).to receive(:contain_repo?).and_return(repo?)
    allow(Y2Packager::ProductSpec).to receive(:base_products).and_return([sles_spec])
    Yast::AutoinstConfig.ProfileInRootPart = false
  end

  describe "#run" do
    let(:sles_spec) do
      instance_double(
        Y2Packager::ProductSpec, name: "SLES", display_name: "SUSE Linux Enterprise Server"
      )
    end

    it "inits console module" do
      expect(Yast::Console).to receive(:Init)

      subject.run
    end

    it "shows progress" do
      expect(Yast::Progress).to receive(:New)

      subject.run
    end

    it "calls iscsi client if linuxrc wants iscsi" do
      expect(Yast::Linuxrc).to receive(:useiscsi).and_return(true)

      expect(Yast::WFM).to receive(:CallFunction).with("inst_iscsi-client", [])

      subject.run
    end

    it "reads profile from root for autoupgrade when linuxrc does not specify profile" do
      allow(Yast::Mode).to receive(:autoupgrade).and_return(true)
      allow(Yast::Linuxrc).to receive(:InstallInf).with("AutoYaST").and_return(nil)

      subject.run

      expect(Yast::AutoinstConfig.ProfileInRootPart).to eq true
    end

    it "analyses system if it is not done already for profile in root" do
      expect(Yast::WFM).to receive(:CallFunction).with("inst_system_analysis", [])
      allow(Yast::Linuxrc).to receive(:InstallInf).with("AutoYaST")
        .and_return("ftp://test.conf/AY.xml")

      subject.run
    end

    it "calls iscsci client import and write if profile contain it" do
      map = { "enabled" => false }
      allow(Yast::Profile).to receive(:current)
        .and_return(Yast::ProfileHash.new("iscsi-client" => map))
      expect(Yast::WFM).to receive(:CallFunction).with("iscsi-client_auto", ["Import", map])
      expect(Yast::WFM).to receive(:CallFunction).with("iscsi-client_auto", ["Write"])

      subject.run
    end

    it "calls fcoe client import and write if profile contain it" do
      map = { "enabled" => false }
      allow(Yast::Profile).to receive(:current)
        .and_return(Yast::ProfileHash.new("fcoe-client" => map))
      expect(Yast::WFM).to receive(:CallFunction).with("fcoe-client_auto", ["Import", map])
      expect(Yast::WFM).to receive(:CallFunction).with("fcoe-client_auto", ["Write"])

      subject.run
    end

    it "reports an error when the product is not specified" do
      allow(Yast::Mode).to receive(:autoupgrade).and_return(false)
      allow(Yast::InstURL).to receive(:installInf2Url).and_return("")

      expect(Yast::Popup).to receive(:LongError)

      expect(subject.run).to eq :abort
    end

    context "when the registration is not enabled in the profile" do
      it "does not try to register the system" do
        expect(Yast::WFM).to_not receive(:CallFunction)
          .with("scc_auto", ["Import", profile["suse_register"]])
        expect(Yast::WFM).to_not receive(:CallFunction).with("scc_auto", ["Write"])

        subject.run
      end

      context "and there are not repositories in the installation medium" do
        let(:repo?) { false }

        it "reports an error" do
          expect(Yast::WFM).to_not receive(:CallFunction)
            .with("scc_auto", ["Import", profile["suse_register"]])
          expect(Yast::WFM).to_not receive(:CallFunction).with("scc_auto", ["Write"])
          expect(Yast::Popup).to receive(:LongError)

          subject.run
        end

        it "returns :abort" do
          expect(subject.run).to eq :abort
        end
      end
    end

    context "when the registration is enabled according to the profile" do
      let(:do_registration) { true }

      before do
        expect(Y2Packager::MediumType).to receive(:online?).and_return(online_medium)
      end

      context "on the Online medium" do
        let(:online_medium) { true }

        it "registers the system" do
          expect(Yast::WFM).to receive(:CallFunction)
            .with("scc_auto", ["Import", profile["suse_register"]])
          expect(Yast::WFM).to receive(:CallFunction).with("scc_auto", ["Write"])
          # fake that registration is available to avoid build requires
          allow(subject).to receive(:registration_module_available?).and_return(true)
          allow(Yast::Profile).to receive(:remove_sections)

          subject.run
        end
      end

      context "on the Full medium" do
        let(:online_medium) { false }

        it "does not register the system" do
          allow(Yast::WFM).to receive(:CallFunction)
          expect(Yast::WFM).to_not receive(:CallFunction).with("scc_auto", anything)
          # fake that registration is available to avoid build requires
          allow(subject).to receive(:registration_module_available?).and_return(true)
          allow(Yast::Profile).to receive(:remove_sections)

          subject.run
        end
      end

    end

    context "when the network is requested to be configured before the proposal" do
      let(:setup_before_proposal) { true }

      it "configures the network" do
        expect(subject).to receive(:autosetup_network)

        subject.run
      end
    end

    #  TODO: more test for profile processing
    it "reports a warning with the list of unsupported section when present in the profile" do
      allow_any_instance_of(Y2Autoinstallation::Importer).to receive(:obsolete_sections)
        .and_return(["unsupported"])

      expect(Yast::Report).to receive(:LongWarning)
      subject.run
    end

    context "when pre-scripts are defined" do
      let(:scripts_return) { :ok }
      let(:read_modified) { :not_found }
      let(:modified) { false }

      before do
        allow(subject).to receive(:autoinit_scripts).and_return(scripts_return)
        allow(subject).to receive(:readModified).and_return(read_modified)
        allow(Yast::AutoinstScripts).to receive(:Import)
        allow(Yast::AutoinstScripts).to receive(:Write)
        allow(subject).to receive(:import_initial_config)
        allow(subject).to receive(:modified_profile?).and_return(modified)
      end

      it "runs pre-scripts" do
        expect(subject).to receive(:autoinit_scripts)
        subject.run
      end

      context "when the pre-scripts modify the profile" do
        let(:modified) { true }

        it "imports the initial configuration (report, general and scripts)" do
          expect(subject).to receive(:import_initial_config)

          subject.run
        end
      end

      context "when applying pre-scripts return :ok" do
        it "finishes the Progress" do
          expect(Yast::Progress).to receive(:Finish)
          subject.run
        end
      end

      context "when applying pre-scripts do not return :ok" do
        let(:scripts_return) { :restart_yast }

        it "returns what was returned by the call" do
          expect(subject.run).to eq(:restart_yast)
        end
      end
    end
  end
end
