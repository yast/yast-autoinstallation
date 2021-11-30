# Copyright (c) [2021] SUSE LLC
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
require "autoinstall/clients/software_auto"
Yast.import "AutoinstSoftware"

describe Y2Autoinstallation::Clients::SoftwareAuto do
  subject(:client) do
    described_class.new
  end

  before do
    Yast::AutoinstSoftware.main
    Yast::PackageAI.main
  end

  describe "#main" do
    let(:args) { [] }

    before do
      allow(Yast::WFM).to receive(:Args) do |n|
        n ? args[n] : args
      end
    end

    describe "'Summary' command" do
      let(:args) { ["Summary"] }

      it "returns the summary from the AutoinstSoftware module" do
        allow(Yast::AutoinstSoftware).to receive(:Summary).and_return("packages summary")
        expect(client.main).to eq("packages summary")
      end
    end

    describe "'Import' command" do
      let(:args) { ["Import", { "packages" => [] }] }

      it "imports the configuration into the AutoinstSoftware module" do
        expect(Yast::AutoinstSoftware).to receive(:Import).with(args[1])
        client.main
      end
    end

    describe "'Reset' command" do
      let(:args) { ["Reset"] }

      it "imports an empty configuration into the AutoinstSoftware module" do
        expect(Yast::AutoinstSoftware).to receive(:Import).with({})
        client.main
      end
    end

    describe "'Read' command" do
      let(:args) { ["Read"] }

      context "when a previously saved software selection exists" do
        it "reads the saved selection" do
          expect(Yast::AutoinstSoftware).to receive(:SavedPackageSelection).and_return(true)
          expect(Yast::AutoinstSoftware).to_not receive(:Read)
          expect(client.main).to eq(true)
        end
      end

      context "when no previously saved software selection exists" do
        before do
          allow(Yast::AutoinstSoftware).to receive(:SavedPackageSelection).and_return(false)
        end

        it "reads the saved selection" do
          expect(Yast::AutoinstSoftware).to receive(:Read).and_return(true)
          expect(client.main).to eq(true)
        end
      end
    end

    describe "'Change' command" do
      let(:args) { ["Change"] }
      let(:local_source) { true }
      let(:base_pattern) { double(Y2Packager::Resolvable, name: "base") }
      let(:yast2_pattern) { double(Y2Packager::Resolvable, name: "yast2_basis") }
      let(:selected_patterns) { [base_pattern] }

      before do
        allow(Yast::UI).to receive(:QueryWidget).with(Id(:location), :Value)
          .and_return(!local_source)
        allow(Yast::UI).to receive(:QueryWidget).with(Id(:localSource), :Value)
          .and_return(local_source)
        allow(Yast::UI).to receive(:UserInput).and_return(:ok)
        allow(Yast::Pkg).to receive(:SourceStartManager)
        allow(Yast::PackagesUI).to receive(:RunPackageSelector).and_return(:next)
        allow(Y2Packager::Resolvable).to receive(:find).with(kind: :pattern)
          .and_return([base_pattern])
        allow(Y2Packager::Resolvable).to receive(:find).with(kind: :pattern, status: :selected)
          .and_return(selected_patterns)
      end

      it "displays a dialog to select the location of the installation source"

      context "when a pattern is preselected for installation" do
        before do
          Yast::AutoinstSoftware.patterns = ["base"]
        end

        it "selects the patterns" do
          expect(Yast::Pkg).to receive(:ResolvableInstall).with("base", :pattern)
          client.main
        end
      end

      context "when the packages proposal includes packages to install" do
        before do
          Yast::PackageAI.toinstall = ["yast2"]
        end

        it "selects the packages" do
          expect(Yast::Pkg).to receive(:PkgInstall).with("yast2")
          client.main
        end
      end

      context "when the packages proposal includes packages to remove" do
        before do
          Yast::PackageAI.toremove = ["dummy"]
        end

        it "deselects the packages" do
          expect(Yast::Pkg).to receive(:PkgTaboo).with("dummy")
          client.main
        end
      end

      it "starts the package manager" do
        expect(Yast::Pkg).to receive(:SourceStartManager)
        expect(Yast::PackagesUI).to receive(:RunPackageSelector).with("mode" => :searchMode)
          .and_return(:next)
        client.main
      end

      context "when patterns and/or packages are selected/deselected" do
        let(:selected_patterns) { [base_pattern, yast2_pattern] }
        let(:selected_packages) { [{ "name" => "yast2" }, { "name" => "git" }] }
        let(:removed_packages) { ["dummy"] }

        before do
          allow(Yast::Pkg).to receive(:FilterPackages).with(false, true, true, true) do
            selected_packages.map { |pkg| pkg["name"] }
          end
          allow(Yast::Pkg).to receive(:GetPackages).with(:selected, true)
            .and_return(selected_packages)
          allow(Yast::Pkg).to receive(:GetPackages).with(:taboo, true)
            .and_return(removed_packages)
        end

        it "updates the proposal and the list of patterns" do
          client.main
          expect(Yast::AutoinstSoftware.patterns).to eq([base_pattern.name, yast2_pattern.name])
          expect(Yast::PackageAI.toinstall).to eq(["yast2", "git"])
          expect(Yast::PackageAI.toremove).to eq(["dummy"])
        end
      end

      it "initializes the pkg target to the root filesystem" do
        expect(Yast::Pkg).to receive(:TargetInit).with("/", false)
        client.main
      end

      context "when the inst-source of the system is selected" do
        let(:local_source) { false }

        it "adds the given repository"
      end
    end

    describe "'SetModified' command" do
      let(:args) { ["SetModified"] }

      it "sets the AutoinstSoftware module as modified" do
        expect { client.main }.to change { Yast::AutoinstSoftware.GetModified }
          .from(false).to(true)
      end
    end

    describe "'GetModified'" do
      let(:args) { ["GetModified"] }

      context "when the AutoinstSoftware module is modified" do
        before do
          Yast::AutoinstSoftware.SetModified
        end

        it "returns true" do
          expect(client.main).to eq(true)
        end
      end

      context "when the PackageAI module is modified" do
        before do
          Yast::PackageAI.SetModified
        end

        it "returns true" do
          expect(client.main).to eq(true)
        end
      end

      context "when AutoinstSofware and PackageAI are not modified" do
        it "returns false" do
          expect(client.main).to eq(false)
        end
      end
    end

    describe "'Export' command" do
      let(:args) { ["Export"] }

      it "returns the export from the AutoinstSoftware module" do
        allow(Yast::AutoinstSoftware).to receive(:Export).and_return({})
        expect(client.main).to eq({})
      end
    end
  end
end
