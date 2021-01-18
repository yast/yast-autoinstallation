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
require "autoinstall/clients/inst_autosetup_upgrade"

# TODO: just temporary workaround for missing require
require "y2packager/resolvable"

describe Y2Autoinstallation::Clients::InstAutosetupUpgrade do
  let(:profile) do
    {
      "general"  => {},
      "software" => {
        "products"        => ["sled"],
        "patterns"        => ["yast-devel"],
        "packages"        => ["vim"],
        "remove-packages" => ["emacs"],
        "remove-patterns" => ["test"],
        "remove-products" => ["sle-desktop"]
      },
      "upgrade"  => { "stop_on_solver_conflict" => true }
    }
  end

  before do
    allow(subject).to receive(:probe_storage)
    allow(Yast::Packages).to receive(:Init)
    allow(Yast::Pkg).to receive(:Resolvables).and_return([])
    allow(Yast::Profile).to receive(:current).and_return(profile)
    # mock other clients call
    allow(Yast::WFM).to receive(:CallFunction).and_return(:next)
    Yast::Update.did_init1 = false
    allow(Yast::Pkg).to receive(:ResolvableInstall)
    allow(Yast::Pkg).to receive(:ResolvableRemove)
    allow(Yast::Pkg).to receive(:PkgSolve).and_return(true)
    allow(Yast::Product).to receive(:FindBaseProducts).and_return([])
  end

  describe "#main" do
    it "shows a progress" do
      expect(Yast::Progress).to receive(:New).at_least(:once)

      subject.main
    end

    it "checks if upgrade is supported" do
      Yast::RootPart.previousRootPartition = ""
      Yast::RootPart.selectedRootPartition = "/dev/sda1"
      expect(Yast::Update).to receive(:IsProductSupportedForUpgrade)

      subject.main
    end

    it "drop obsolete packages" do
      expect(Yast::Update).to receive(:DropObsoletePackages)

      subject.main
    end

    it "install all needed packages for accessing installation repositories" do
      allow(Yast::Packages).to receive(:sourceAccessPackages).and_return(["cifs-mount"])
      expect(Yast::Pkg).to receive(:ResolvableInstall).with("cifs-mount", :package)

      subject.main
    end

    it "select for installation all product renames" do
      allow(Yast::AddOnProduct).to receive(:missing_upgrades).and_return(["sle-development-tools"])
      expect(Yast::Pkg).to receive(:ResolvableInstall).with("sle-development-tools", :product)

      subject.main
    end

    it "install/removes patterns, products anad packages according to profile" do
      expect(Yast::Pkg).to receive(:ResolvableInstall).with("sled", :product)
      expect(Yast::Pkg).to receive(:ResolvableInstall).with("yast-devel", :pattern)
      expect(Yast::Pkg).to receive(:ResolvableInstall).with("vim", :package)
      expect(Yast::Pkg).to receive(:ResolvableRemove).with("emacs", :package)
      expect(Yast::Pkg).to receive(:ResolvableRemove).with("test", :pattern)
      expect(Yast::Pkg).to receive(:ResolvableRemove).with("sle-desktop", :product)

      subject.main
    end

    it "tries to solve upgrade path do" do
      expect(Yast::Pkg).to receive(:PkgSolve).and_return(true)

      subject.main
    end

    it "stop for confirmation if solve failing and user require it" do
      subject.main

      expect(Yast::AutoinstConfig.Confirm).to eq true
    end
  end
end
