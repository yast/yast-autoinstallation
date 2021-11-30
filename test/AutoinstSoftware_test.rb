#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "AutoinstSoftware"
Yast.import "AutoinstData"
Yast.import "Profile"

describe Yast::AutoinstSoftware do

  subject { Yast::AutoinstSoftware }

  let(:profile) { FIXTURES_PATH.join("profiles", "software.xml").to_s }

  before(:each) do
    Yast::AutoinstData.main
    Yast::PackagesProposal.ResetAll
    subject.main
    Yast::Profile.ReadXML(profile)
  end

  describe "post-software installation" do
    it "installs packages only if they have not already been installed" do
      Yast::AutoinstData.post_packages = ["a2"]
      expect(Yast::PackageSystem).to receive(:Installed).with("a1").and_return(false)
      expect(Yast::PackageSystem).to receive(:Installed).with("a2").and_return(false)
      expect(Yast::PackageSystem).to receive(:Installed).with("a3").and_return(true)
      subject.Import(Yast::Profile.current["software"])

      expect(Yast::AutoinstData.send(:post_packages)).to eq(["a1", "a2"])
    end
  end

  describe "#add_additional_packages" do
    let(:pkgs) { ["NetworkManager"] }
    let(:available_packages) { ["a1", "a2", "a3", "NetworkManager"] }

    before do
      allow(Yast::Pkg).to receive(:GetPackages)
        .with(:available, true).and_return(available_packages)
      subject.Import(Yast::Profile.current["software"])
    end

    it "appends the given list to the one to be installed" do
      Yast::AutoinstSoftware.add_additional_packages(pkgs)
      expect(Yast::PackagesProposal.GetResolvables("autoyast", :package))
        .to include("NetworkManager")
    end

    context "when the packages given are not available" do
      let(:available_packages) { ["a1", "a2", "a3"] }

      it "the packages are not added" do
        Yast::AutoinstSoftware.add_additional_packages(pkgs)
        expect(Yast::PackagesProposal.GetResolvables("NetworkManager", :package))
          .to_not include("NetworkManager")
      end
    end
  end

  describe "#Import" do
    let(:software) do
      {
        "patterns"        => ["base", "yast2_basis"],
        "packages"        => ["yast2", "other"],
        "post-patterns"   => ["gnome"],
        "post-packages"   => ["pkg1"],
        "remove-packages" => ["dummy"],
        "kernel"          => "kernel-vanilla"
      }
    end

    let(:available_pkgs) { ["yast2"] }

    before do
      allow(Yast::Pkg).to receive(:GetPackages).with(:available, true).and_return(available_pkgs)
    end

    it "saves the list of patterns and packages to install and remove" do
      subject.Import(software)
      expect(subject.patterns).to eq(["base", "yast2_basis"])
      expect(Yast::PackagesProposal.GetResolvables("autoyast", :package)).to eq(["yast2", "other"])
      expect(Yast::PackagesProposal.GetTaboos("autoyast")).to eq(["dummy"])
    end

    it "sets the kernel package to install" do
      subject.Import(software)
      expect(subject.kernel).to eq("kernel-vanilla")
    end

    it "saves the list of patterns and packages to install during 2nd stage" do
      subject.Import(software)
      expect(Yast::AutoinstData.post_patterns).to eq(["gnome"])
      expect(Yast::AutoinstData.post_packages).to eq(["pkg1"])
    end
  end

  describe "#Export" do
    it "puts product definition into the exported profile" do
      expect(Yast::Product)
        .to receive(:FindBaseProducts)
        .and_return([{ "name" => "LeanOS" }])

      profile = subject.Export

      expect(profile).to have_key("products")
      expect(profile["products"]).to eql ["LeanOS"]
    end

    it "raises an error when multiple products were found" do
      expect(Yast::Product)
        .to receive(:FindBaseProducts)
        .and_return(
          [
            { "name" => "LeanOS" },
            { "name" => "AgileOS" }
          ]
        )

      expect { subject.Export }.to raise_error(RuntimeError, "Found multiple base products")
    end
  end

  describe "selecting packages for installation" do

    before(:each) do
      allow(subject).to receive(:autoinstPackages).and_return(["a1"])
      expect(Yast::Packages).to receive(:ComputeSystemPackageList).and_return(["a2", "a3", "a4"])
      expect(Yast::Pkg).to receive(:DoProvide).with(["a1"]).and_return("a1" => "not found")
    end

    it "shows a popup if some packages have not been found" do
      subject.Import(Yast::Profile.current["software"])
      expect(Yast::Pkg).to receive(:DoProvide).with(["a2", "a3", "a4"]).and_return({})
      expect(Yast::Report).to receive(:Error)
      subject.SelectPackagesForInstallation()
    end

    it "shows a popup for not found packages which have been selected by AY configuration only" do
      subject.Import(Yast::Profile.current["software"])
      expect(Yast::Pkg).to receive(:DoProvide).with(["a2", "a3", "a4"])
        .and_return("a4" => "not found")
      # a4 is not in the software/packages section
      expect(Yast::Report).to receive(:Error)
        .with("These packages cannot be found in the software repositories:\na1: not found\n")
      subject.SelectPackagesForInstallation()
    end

    it "shows no popup if no software section has been defined in the AY configuration" do
      subject.Import({})
      expect(Yast::Pkg).to receive(:DoProvide).with(["a2", "a3", "a4"])
        .and_return("a4" => "not found")
      expect(Yast::Report).to_not receive(:Error)
      subject.SelectPackagesForInstallation()
    end
  end

  describe "#locked_packages" do
    before do
      expect(Yast::Pkg).to receive(:GetPackages).with(:taboo, true).and_return(["foo"])
      expect(Yast::Pkg).to receive(:GetPackages).with(:available, true).and_return(["bar"])
    end

    it "returns packages locked by user" do
      # just mock only the needed attributes
      expect(Yast::Pkg).to receive(:PkgPropertiesAll).with("foo")
        .and_return(["transact_by" => :user, "status" => :taboo])
      expect(Yast::Pkg).to receive(:PkgPropertiesAll).with("bar")
        .and_return(["transact_by" => :user, "status" => :available])
      expect(subject.locked_packages).to include("foo").and include("bar")
    end

    it "ignores packages changed by the solver" do
      # just mock only the needed attributes
      expect(Yast::Pkg).to receive(:PkgPropertiesAll).with("foo")
        .and_return(["transact_by" => :solver, "status" => :taboo])
      expect(Yast::Pkg).to receive(:PkgPropertiesAll).with("bar")
        .and_return(["transact_by" => :solver, "status" => :available])
      expect(subject.locked_packages).to be_empty
    end
  end

  describe "#Write" do
    let(:base_product) { { "name" => "Leap" } }
    let(:selected_product) do
      instance_double(Y2Packager::Product, select: nil)
    end
    let(:storage_manager) do
      instance_double(Y2Storage::StorageManager, staging: devicegraph)
    end

    let(:devicegraph) do
      instance_double(Y2Storage::Devicegraph, used_features: storage_features)
    end

    let(:storage_features) do
      instance_double(Y2Storage::StorageFeaturesList, pkg_list: storage_pkgs)
    end

    let(:storage_pkgs) { ["btrfsprogs"] }
    let(:solver_result) { true }

    let(:storage_pkg_handler) do
      instance_double(Y2Storage::PackageHandler, set_proposal_packages: true)
    end

    let(:pkgs_to_install) { ["openSUSE-release"] }

    before do
      allow(Yast::Packages).to receive(:Init)
      allow(Yast::Product).to receive(:FindBaseProducts).and_return([base_product])
      allow(Yast::Pkg).to receive(:PkgApplReset)
      allow(Yast::Pkg).to receive(:PkgSolve).and_return(solver_result)
      allow(Y2Storage::StorageManager).to receive(:instance).and_return(storage_manager)
      allow(Y2Storage::PackageHandler).to receive(:new).with(storage_pkgs)
        .and_return(storage_pkg_handler)
      allow(Yast::SpaceCalculation).to receive(:ShowPartitionWarning)
      allow(Yast::AutoinstFunctions).to receive(:selected_product)
        .and_return(selected_product)
      allow(subject).to receive(:SelectPackagesForInstallation)
      allow(Yast::Packages).to receive(:ComputeSystemPackageList).and_return(pkgs_to_install)
      allow(Yast::Packages).to receive(:SelectSystemPatterns)
      subject.kernel = nil
    end

    it "selects packages for installation" do
      expect(Yast::Packages).to receive(:ComputeSystemPackageList)
      expect(subject).to receive(:SelectPackagesForInstallation)
      subject.Write
    end

    it "selects system patterns" do
      expect(Yast::Packages).to receive(:SelectSystemPatterns).with(false)
      subject.Write
    end

    it "sets base products for installation" do
      expect(Yast::Pkg).to receive(:ResolvableInstall).with("Leap", :product)
      expect(selected_product).to receive(:select)
      subject.Write
    end

    it "selects required storage packages for installation" do
      expect(storage_pkg_handler).to receive(:set_proposal_packages)
      subject.Write
    end

    context "when a kernel package is selected" do
      let(:pkgs_to_install) { ["kernel-default"] }

      before do
        subject.kernel = "kernel-vanilla"
      end

      it "removes other kernel packages" do
        expect(Yast::Pkg).to receive(:PkgTaboo).with("kernel-default")
        subject.Write
      end
    end

    context "when packages are preselected for removal" do
      before do
        Yast::PackagesProposal.AddTaboos("autoyast", ["dummy"])
      end

      it "removes the packages" do
        expect(Yast::Pkg).to receive(:PkgTaboo).with("dummy")
        expect(Yast::Pkg).to receive(:DoRemove).with(["dummy"])
        subject.Write
      end
    end

    context "when the resolver fails" do
      let(:solver_result) { false }

      it "displays an error" do
        expect(Yast::Report).to receive(:LongError).with(/package resolver run failed/)
        subject.Write
      end
    end
  end
end
