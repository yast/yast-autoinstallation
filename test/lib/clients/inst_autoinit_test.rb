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

    context "when using the Full medium" do
      it "reports an error when the product is not specified" do
        allow(Y2Packager::MediumType).to receive(:online?).and_return(false)
        allow(Y2Packager::MediumType).to receive(:offline?).and_return(true)
        allow(Yast::Mode).to receive(:autoupgrade).and_return(false)

        expect(Yast::Popup).to receive(:LongError)

        expect(subject.run).to eq :abort
      end
    end

    context "when using the Online medium for an installation" do
      let(:do_registration) { false }
      let(:setup_before_proposal) { false }
      let(:profile) do
        {
          "suse_register" => { "do_registration" => do_registration },
          "networking"    => { "setup_before_proposal" => setup_before_proposal }
        }
      end

      before do
        allow(Yast::Mode).to receive(:autoupgrade).and_return(false)
        allow(Yast::Profile).to receive(:current).and_return(profile)
      end

      context "and the network is requested to be configured before the proposal" do
        let(:setup_before_proposal) { true }

        it "configures the network" do
          expect(subject).to receive(:autosetup_network)

          subject.run
        end
      end

      context "and the registration is disabled or not present in the profile" do
        let(:do_registration) { false }

        it "does not try to register the system" do
          expect(Yast::WFM).to_not receive(:CallFunction)
            .with("scc_auto", ["Import", profile["suse_register"]])
          expect(Yast::WFM).to_not receive(:CallFunction).with("scc_auto", ["Write"])

          subject.run
        end

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

      context "and the registration is enabled according to the profile" do
        let(:do_registration) { true }

        it "registers system" do
          expect(Yast::WFM).to receive(:CallFunction)
            .with("scc_auto", ["Import", profile["suse_register"]])
          expect(Yast::WFM).to receive(:CallFunction).with("scc_auto", ["Write"])
          # fake that registration is available to avoid build requires
          allow(subject).to receive(:registration_module_available?).and_return(true)
          allow(Yast::Profile).to receive(:remove_sections)

          subject.run
        end
      end
    end

    #  TODO: more test for profile processing
  end
end
