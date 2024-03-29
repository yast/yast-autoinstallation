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

require_relative "../../test_helper"
require "autoinstall/clients/ayast_setup"

require "yast"

module Yast
  class DummyClient < Module
    include Y2Autoinstall::Clients::AyastSetup
    attr_accessor :dopackages
  end
end

Yast.import "Profile"

describe "Y2Autoinstall::Clients::AyastSetup" do
  let(:subject) { Yast::DummyClient.new }
  let(:profile) do
    {
      "general"  => { "mode" => { "confirm" => true } },
      "software" => { "post-packages" => packages }
    }
  end
  let(:packages) { ["vim"] }
  let(:dopackages) { false }

  let(:client) do
    instance_double(Y2Autoinstall::Clients::AyastSetup, Setup: true)
  end

  describe "#main" do
    it "Start the ayast_setup client" do
      expect(client.Setup).to eq true
    end
  end

  describe "#Setup" do
    before do
      Yast::Profile.current = profile
      allow(Yast::AutoInstall).to receive(:Save)
      allow(Yast::AutoinstGeneral).to receive(:Import)
      allow(Yast::WFM).to receive(:CallFunction)
      allow(Yast::Mode).to receive(:SetMode)
      allow(Yast::Stage).to receive(:Set)
      allow(Yast::Package).to receive(:Installed).and_return(true)
      allow(Yast::Pkg).to receive(:TargetInit)
      allow(subject).to receive(:restart_initscripts)
    end

    it "saves the current profile if modified" do
      expect(Yast::AutoInstall).to receive(:Save)

      subject.Setup
    end

    it "calls the inst_autopost client" do
      expect(Yast::WFM).to receive(:CallFunction).with("inst_autopost", [])

      subject.Setup
    end

    context "when install_packages is set to true" do
      it "installs given post installation packages / patterns when not installed yet" do
        expect(Yast::Package).to receive(:Installed).and_return(false)
        expect(Yast::AutoinstSoftware).to receive(:addPostPackages).with(["vim"])
        expect(Yast::WFM).to receive(:CallFunction).with("inst_rpmcopy", [])

        subject.Setup(install_packages: true)
      end
    end

    context "when install_packages is set to specified" do
      it "installs given post installation packages / patterns when not installed yet" do
        expect(Yast::Package).to receive(:Installed).and_return(false)
        expect(Yast::AutoinstSoftware).to receive(:addPostPackages).with(["vim"])
        expect(Yast::WFM).to receive(:CallFunction).with("inst_rpmcopy", [])

        subject.Setup
      end
    end

    context "when install_packages is set to false" do
      it "does not try to install given post installation packages / patterns" do
        expect(Yast::WFM).to_not receive(:CallFunction).with("inst_rpmcopy", [])

        subject.Setup(install_packages: false)
      end
    end

    it "runs inst_autoconfigure client" do
      expect(Yast::WFM).to receive(:CallFunction).with("inst_autoconfigure", [])

      subject.Setup
    end

    it "restarts AutoYaST initscripts" do
      expect(subject).to receive(:restart_initscripts)

      subject.Setup
    end

    it "does not add a networking section when it is not defined in the profile" do
      expect(Yast::Profile.current.keys).to_not include("networking")
      subject.Setup
      expect(Yast::Profile.current.keys).to_not include("networking")
    end

    it "imports general settings" do
      settings = { "mode" => { "confirm" => true } }
      expect(Yast::AutoinstGeneral).to receive(:Import).with(settings)
      subject.Setup
    end
  end
end
