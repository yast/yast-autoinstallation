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
  let(:product_name) { "sled" }
  let(:profile) do
    {
      "general"  => {},
      "software" => {
        "products"        => [product_name],
        "patterns"        => ["yast-devel"],
        "packages"        => ["vim"],
        "remove-packages" => ["emacs"],
        "remove-patterns" => ["test"],
        "remove-products" => ["sle-desktop"]
      },
      "upgrade"  => { "stop_on_solver_conflict" => true }
    }
  end

  let(:product) do
    Y2Packager::Product.new(name: product_name)
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
    # do not change the current language, using translated messages
    # would break test expectations
    allow(Yast::WFM).to receive(:SetLanguage)
    allow(Yast::UI).to receive(:SetLanguage)
    allow(Yast::AutoinstFunctions).to receive(:available_base_products).and_return([])
    allow(Yast::AutoinstFunctions).to receive(:selected_product).and_return(product)
    allow(Yast::AutoinstSoftware).to receive(:merge_product)
    allow(Yast::Product).to receive(:FindBaseProducts).and_return([])
    allow(Yast::ProductControl).to receive(:RunFrom).and_return(:next)
  end

  describe "#main" do
    it "shows a progress" do
      expect(Yast::Progress).to receive(:New).at_least(:once)

      subject.main
    end

    it "merges the selected product workflow" do
      expect(Yast::AutoinstSoftware).to receive(:merge_product).with(product)

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
      expect(Yast::Pkg).to receive(:ResolvableInstall).with(product_name, :product)
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

    context "when a package is proposed for installation" do
      before do
        allow(Yast::WFM).to receive(:CallFunction).with("bootloader_auto", any_args) do
          Yast::PackagesProposal.AddResolvables("yast2-bootloader", :package, ["shim"])
        end
      end

      it "install those packages" do
        expect(Yast::Pkg).to receive(:ResolvableInstall).with("shim", :package)
        subject.main
      end
    end
  end
end
