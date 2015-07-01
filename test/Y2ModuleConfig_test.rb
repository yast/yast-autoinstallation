#!/usr/bin/env rspec

require_relative "test_helper"
require "yaml"

Yast.import "Y2ModuleConfig"
Yast.import "Desktop"
Yast.import "Profile"

describe Yast::Y2ModuleConfig do
  FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures')
  DESKTOP_DATA = YAML::load_file(File.join(FIXTURES_PATH, 'desktop_files', 'desktops.yml'))

  before do
    allow(Yast::WFM).to receive(:ClientExists).with("audit-laf_auto").and_return(false)
    allow(Yast::WFM).to receive(:ClientExists).with("autofs_auto").and_return(false)
    allow(Yast::WFM).to receive(:ClientExists).with("ca_mgm_auto").and_return(false)
    allow(Yast::WFM).to receive(:ClientExists).with("deploy_image_auto").and_return(true)
    allow(Yast::WFM).to receive(:ClientExists).with("files_auto").and_return(true)
    allow(Yast::WFM).to receive(:ClientExists).with("firstboot_auto").and_return(false)
    allow(Yast::WFM).to receive(:ClientExists).with("general_auto").and_return(true)
    allow(Yast::WFM).to receive(:ClientExists).with("language_auto").and_return(false)
    allow(Yast::WFM).to receive(:ClientExists).with("pxe_auto").and_return(false)
    allow(Yast::WFM).to receive(:ClientExists).with("restore_auto").and_return(false)
    allow(Yast::WFM).to receive(:ClientExists).with("runlevel_auto").and_return(false)
    allow(Yast::WFM).to receive(:ClientExists).with("scripts_auto").and_return(true)
    allow(Yast::WFM).to receive(:ClientExists).with("software_auto").and_return(true)
    allow(Yast::WFM).to receive(:ClientExists).with("sshd_auto").and_return(false)
    allow(Yast::WFM).to receive(:ClientExists).with("sysconfig_auto").and_return(false)
    allow(Yast::WFM).to receive(:ClientExists).with("unknown_profile_item_1_auto").and_return(false)
    allow(Yast::WFM).to receive(:ClientExists).with("unknown_profile_item_2_auto").and_return(false)
    allow(Yast::WFM).to receive(:ClientExists).with("partitioning_auto").and_return(false)
    allow(Yast::WFM).to receive(:ClientExists).with("upgrade_auto").and_return(false)
  end

  describe "#unhandled_profile_sections" do
    let(:profile_unhandled) { File.join(FIXTURES_PATH, 'profiles', 'unhandled_and_obsolete.xml') }

    it "returns all unsupported and unknown profile sections" do
      Yast::Profile.ReadXML(profile_unhandled)
      Yast::Y2ModuleConfig.instance_variable_set("@ModuleMap", DESKTOP_DATA)

      expect(Yast::Y2ModuleConfig.unhandled_profile_sections.sort).to eq(
        [
          "audit-laf", "autofs", "ca_mgm", "firstboot", "language", "restore",
          "runlevel", "sshd", "sysconfig", "unknown_profile_item_1",
          "unknown_profile_item_2"
        ].sort
      )
    end
  end

  describe "#unsupported_profile_sections" do
    let(:profile_unsupported) { File.join(FIXTURES_PATH, 'profiles', 'unhandled_and_obsolete.xml') }

    it "returns all unsupported profile sections" do
      Yast::Profile.ReadXML(profile_unsupported)
      Yast::Y2ModuleConfig.instance_variable_set("@ModuleMap", DESKTOP_DATA)

      expect(Yast::Y2ModuleConfig.unsupported_profile_sections.sort).to eq(
        ["autofs", "restore", "sshd"].sort
      )
    end
  end
end
