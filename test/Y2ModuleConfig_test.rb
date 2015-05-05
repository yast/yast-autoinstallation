#!/usr/bin/env rspec

require_relative "test_helper"
require "yaml"

Yast.import "Y2ModuleConfig"
Yast.import "Desktop"
Yast.import "Profile"

include Yast::Logger

FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures')
DESKTOP_DATA = YAML::load_file(File.join(FIXTURES_PATH, 'desktop_files', 'desktops.yml'))

describe Yast::Y2ModuleConfig do
  describe "#unhandled_profile_sections" do
    let(:profile_unhandled) { File.join(FIXTURES_PATH, 'profiles', 'unhandled_and_obsolete.xml') }

    it "returns all unsupported and unknown profile sections" do
      Yast::Profile.ReadXML(profile_unhandled)
      Yast::Y2ModuleConfig.instance_variable_set("@ModuleMap", DESKTOP_DATA)

      expect(Yast::Y2ModuleConfig.unhandled_profile_sections.sort).to eq(
        [
          "audit-laf", "autofs", "ca_mgm", "firstboot", "language", "restore",
          "runlevel", "sshd", "sysconfig", "unknown_profile_item_1",
          "unknown_profile_item_2", "users"
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
