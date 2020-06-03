#!/usr/bin/env rspec

require_relative "test_helper"
require "yaml"

Yast.import "Y2ModuleConfig"
Yast.import "Desktop"
Yast.import "Profile"

describe Yast::Y2ModuleConfig do

  DESKTOP_DATA = YAML.load_file(FIXTURES_PATH.join("desktop_files", "desktops.yml"))
  DESKTOP_GROUPS = YAML.load_file(FIXTURES_PATH.join("desktop_files", "groups.yml"))
  AVAILABLE_CLIENTS = ["deploy_image_auto", "files_auto", "general_auto", "scripts_auto",
                       "software_auto", "services-manager_auto"].freeze

  before do
    allow(Yast::WFM).to receive(:ClientExists) { |c| AVAILABLE_CLIENTS.include?(c) }
    allow(Yast::Desktop).to receive(:Groups).and_return(DESKTOP_GROUPS)
    allow(Yast::Desktop).to receive(:Modules).and_return(DESKTOP_DATA)
    subject.main
  end

  describe "#unhandled_profile_sections" do
    let(:profile_unhandled) { File.join(FIXTURES_PATH, "profiles", "unhandled_and_obsolete.xml") }

    it "returns all unsupported and unknown profile sections" do
      Yast::Profile.ReadXML(profile_unhandled)

      expect(Yast::Y2ModuleConfig.unhandled_profile_sections).to contain_exactly(
        "audit-laf", "autofs", "ca_mgm", "cobbler", "firstboot", "inetd", "language",
        "restore", "security", "sshd", "sysconfig", "unknown_profile_item_1",
        "unknown_profile_item_2"
      )
    end
  end

  describe "#unsupported_profile_sections" do
    let(:profile_unsupported) { File.join(FIXTURES_PATH, "profiles", "unhandled_and_obsolete.xml") }

    it "returns all unsupported profile sections" do
      Yast::Profile.ReadXML(profile_unsupported)

      expect(Yast::Y2ModuleConfig.unsupported_profile_sections).to contain_exactly(
        "autofs", "ca_mgm", "cobbler", "inetd", "restore", "sshd"
      )
    end
  end

  describe "#ReadMenuEntries" do
    it "returns the modules and groups for the given modes" do
      modules, groups = subject.ReadMenuEntries(["configure"])
      expect(modules.keys).to eq(
        ["add-on", "bootloader", "general", "partitioning", "report", "software"]
      )
      expect(groups.keys).to eq(
        ["Hardware", "Misc", "Net_advanced", "Security", "Software", "Support", "System"]
      )
    end

    it "sets the client if missing" do
      modules, _groups = subject.ReadMenuEntries(["configure"])
      add_on = modules["add-on"]
      expect(add_on["X-SuSE-YaST-AutoInstClient"]).to eq("add-on_auto")
    end
  end

  describe "#ModuleConfig" do
    it "returns the modules in a hash indexed by name" do
      modules = subject.ModuleMap
      expect(modules["lan"]).to be_a(Hash)
    end

    it "returns the modules with 'all' and 'configure' mode" do
      modules = subject.ModuleMap
      expect(modules).to_not have_key("configuration-management")
    end

    context "during autoinstallation" do
      before do
        allow(Yast::Mode).to receive(:autoinst).and_return(true)
        subject.main
      end

      it "returns the modules with 'all' and 'write' modes" do
        modules = subject.ModuleMap
        expect(modules).to have_key("configuration-management")
      end
    end
  end

  describe "#getModuleConfig" do
    let(:modules) do
      [
        # modules
        { "add-on"     => { "Name" => "Add-On Products" },
          "bootloader" => { "Name" => "Boot Loader" } },
        # groups
        {}
      ]
    end

    before do
      allow(Yast::Y2ModuleConfig).to receive(:ReadMenuEntries).with(%w[all configure write])
        .and_return(modules)
    end

    context "if the module is defined" do
      it "returns module config" do
        expect(Yast::Y2ModuleConfig.getModuleConfig("bootloader")).to eq(
          "res" => "bootloader", "data" => { "Name" => "Boot Loader" }
        )
      end
    end

    context "if the module is undefined" do
      it "returns nil" do
        expect(Yast::Y2ModuleConfig.getModuleConfig("non-existant-module")).to be_nil
      end
    end
  end

  describe "#resource_aliases_map" do
    let(:module_map) { { "custom" => custom_module } }

    before do
      allow(subject).to receive(:ModuleMap).and_return(module_map)
    end

    context "when some module is aliased" do
      let(:custom_module) do
        { "Name"                                => "Custom module",
          "X-SuSE-YaST-AutoInstResourceAliases" => "alias1,alias2" }
      end

      it "maps aliases to the resource" do
        expect(subject.resource_aliases_map)
          .to eq("alias1" => "custom", "alias2" => "custom")
      end
    end

    context "when some module is aliased and an alternative name was specified" do
      let(:custom_module) do
        { "Name"                                => "Custom module",
          "X-SuSE-YaST-AutoInstResource"        => "custom-resource",
          "X-SuSE-YaST-AutoInstResourceAliases" => "alias1,alias2" }
      end

      it "maps aliases to the alternative resource name" do
        expect(subject.resource_aliases_map)
          .to eq("alias1" => "custom-resource", "alias2" => "custom-resource")
      end
    end

    context "when no module is aliased" do
      let(:custom_module) do
        { "Name" => "Custom module" }
      end

      it "returns an empty map" do
        expect(subject.resource_aliases_map).to eq({})
      end
    end
  end

  describe "#required_packages" do
    context "files needed for the check are not installed" do
      it "returns an empty hash" do
        allow(File).to receive(:exist?).with("/usr/share/YaST2/schema/autoyast/rnc/includes.rnc")
          .and_return(false)
        expect(subject.required_packages([])).to eq({})
      end
    end

    context "all files needed for the check are installed" do
      before do
        allow(File).to receive(:exist?).with("/usr/share/YaST2/schema/autoyast/rnc/includes.rnc")
          .and_return(true)
      end

      context "no rng file found for the given AY section" do
        it "returns a hash with an empty package array" do
          expect(Yast::SCR).to receive(:Execute).with(Yast::Path.new(".target.bash_output"),
            "/usr/bin/grep -l \"<define name=\\\"not-found\\\">\" " \
              "/usr/share/YaST2/schema/autoyast/rng/*.rng")
            .and_return("exit" => 1, "stderr" => "", "stdout" => "")
          expect(subject.required_packages(["not-found"])).to eq("not-found"=>[])
        end
      end

      context "rng file found for the given AY section" do
        before do
          allow(Yast::SCR).to receive(:Execute).with(Yast::Path.new(".target.bash_output"),
            "/usr/bin/grep -l \"<define name=\\\"firstboot\\\">\" " \
              "/usr/share/YaST2/schema/autoyast/rng/*.rng")
            .and_return("exit" => 0, "stderr" => "",
            "stdout" => "/usr/share/YaST2/schema/autoyast/rng/firstboot.rng\n")
          allow(File).to receive(:readlines)
            .with("/usr/share/YaST2/schema/autoyast/rnc/includes.rnc")
            .and_return(["include 'firstboot.rnc' # yast2-firstboot\n",
                         "include 'pxe.rnc' # autoyast2\n"])
        end

        context "regarding rnc files does not belong to any package" do
          it "returns a hash with an empty package array" do
            expect(Yast::SCR).to receive(:Execute).with(Yast::Path.new(".target.bash_output"),
              "/usr/bin/grep -l \"<define name=\\\"fake\\\">\" " \
                "/usr/share/YaST2/schema/autoyast/rng/*.rng")
              .and_return("exit" => 0, "stderr" => "",
              "stdout" => "/usr/share/YaST2/schema/autoyast/rng/fake.rng\n")
            expect(subject.required_packages(["fake"])).to eq("fake"=>[])
          end
        end

        context "regarding rnc files belongs to a package" do
          it "returns a hash with needed package list" do
            expect(Yast::PackageSystem).to receive(:Installed).with("yast2-firstboot")
              .and_return(false)
            expect(subject.required_packages(["firstboot"])).to eq("firstboot"=>["yast2-firstboot"])
          end
        end
      end
    end
  end
end
