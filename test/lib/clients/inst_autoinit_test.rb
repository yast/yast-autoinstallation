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
  before do
    allow(Yast::UI).to receive(:UserInput).and_return(:next)
    allow(Yast::WFM).to receive(:CallFunction).and_return(true)
    # can easily ends up in endless loop
    allow(subject).to receive(:ProfileSourceDialog).and_return("")
    allow(Yast::Linuxrc).to receive(:useiscsi).and_return(false)
    allow(Yast::Linuxrc).to receive(:InstallInf).and_return(nil)
    allow(Yast::ProfileLocation).to receive(:Process).and_return(true)
    allow(Yast::Profile).to receive(:ReadXML).and_return(true)
    allow(Yast::Profile).to receive(:current).and_return({})
    allow(Yast::Mode).to receive(:autoupgrade).and_return(true)
    allow(Yast::AutoinstFunctions).to receive(:available_base_products).and_return([])
    allow(Y2Packager::MediumType).to receive(:online?).and_return(true)
    Yast::AutoinstConfig.ProfileInRootPart = false

  end

  describe "#run" do
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
      allow(Yast::Profile).to receive(:current).and_return("iscsi-client" => map)
      expect(Yast::WFM).to receive(:CallFunction).with("iscsi-client_auto", ["Import", map])
      expect(Yast::WFM).to receive(:CallFunction).with("iscsi-client_auto", ["Write"])

      subject.run
    end

    it "calls fcoe client import and write if profile contain it" do
      map = { "enabled" => false }
      allow(Yast::Profile).to receive(:current).and_return("fcoe-client" => map)
      expect(Yast::WFM).to receive(:CallFunction).with("fcoe-client_auto", ["Import", map])
      expect(Yast::WFM).to receive(:CallFunction).with("fcoe-client_auto", ["Write"])

      subject.run
    end

    it "reports error for installation with full medium without specified product" do
      allow(Y2Packager::MediumType).to receive(:online?).and_return(false)
      allow(Y2Packager::MediumType).to receive(:offline?).and_return(true)
      allow(Yast::Mode).to receive(:autoupgrade).and_return(false)

      expect(Yast::Popup).to receive(:LongError)

      expect(subject.run).to eq :abort
    end

    it "registers system for installation with online medium" do
      map = { "suse_register" => { "do_registration" => true } }
      allow(Yast::Mode).to receive(:autoupgrade).and_return(false)
      allow(Yast::Profile).to receive(:current).and_return(map)
      expect(Yast::WFM).to receive(:CallFunction)
        .with("scc_auto", ["Import", map["suse_register"]])
      expect(Yast::WFM).to receive(:CallFunction).with("scc_auto", ["Write"])
      # fake that registration is available to avoid build requires
      allow(subject).to receive(:registration_module_available?).and_return(true)
      allow(Yast::Profile).to receive(:remove_sections)

      subject.run
    end

    it "reports error for installation with online medium without register section" do
      map = { "suse_register" => { "do_registration" => false } }
      allow(Yast::Mode).to receive(:autoupgrade).and_return(false)
      allow(Yast::Profile).to receive(:current).and_return(map)
      expect(Yast::WFM).to_not receive(:CallFunction)
        .with("scc_auto", ["Import", map["suse_register"]])
      expect(Yast::WFM).to_not receive(:CallFunction).with("scc_auto", ["Write"])
      expect(Yast::Popup).to receive(:LongError)

      expect(subject.run).to eq :abort
    end

    #  TODO: more test for profile processing
    it "reports a warning with the list of unsupported section when present in the profile" do
      allow(Yast::Y2ModuleConfig).to receive(:unsupported_profile_sections)
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
