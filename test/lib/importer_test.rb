# Copyright (c) [2020] SUSE LLC
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

require_relative "../test_helper"
require "autoinstall/importer"
require "autoinstall/entries/registry"

describe Y2Autoinstallation::Importer do
  subject { described_class.new(profile) }

  let(:module_map) do
    path = File.expand_path("../fixtures/desktop_files/desktops.yml", __dir__)
    YAML.safe_load(File.read(path))
  end

  let(:groups) do
    path = File.expand_path("../fixtures/desktop_files/groups.yml", __dir__)
    YAML.safe_load(File.read(path))
  end

  let(:registry) { Y2Autoinstallation::Entries::Registry.instance }

  before do
    # reset singleton
    allow(Yast::Desktop).to receive(:Modules)
      .and_return(module_map)
    allow(Yast::Desktop).to receive(:Groups)
      .and_return(module_map)
    reset_singleton(Y2Autoinstallation::Entries::Registry)
  end

  describe "#unhandled_sections" do
    let(:profile) { { "bootloader" => {}, "upgrade" => {}, "scripts" => {}, "not-exists" => {} } }

    it "returns array without sections with desktop file" do
      expect(subject.unhandled_sections).to_not include("bootloader")
    end

    it "returns array without generic sections" do
      expect(subject.unhandled_sections).to_not include("upgrade")
    end

    it "returns array without sections that has auto client" do
      expect(subject.unhandled_sections).to_not include("scripts")
    end

    it "returns array with remaining section keys" do
      expect(subject.unhandled_sections).to eq(["not-exists"])
    end
  end

  describe "obsolete_sections" do
    let(:profile) { { "scripts" => {}, "not-exists" => {}, "sshd" => {} } }

    it "returns obsolete sections in profile" do
      expect(subject.obsolete_sections).to eq(["sshd"])
    end
  end

  describe "#import_sections" do
    let(:profile) do
      {
        "users"      => ["username" => "root", "uid" => "0"],
        "groups"     => ["groupname" => "wheel"],
        "bootloader" => {},
        "runlevel"   => {}
      }
    end

    before do
      allow(Yast::WFM).to receive(:CallFunction)
    end

    it "imports section according to description" do
      expect(Yast::WFM).to receive(:CallFunction).with("bootloader_auto", ["Import", {}])

      subject.import_sections
    end

    it "handles description with multiple sections" do
      expected_data = {
        "users"  => ["username" => "root", "uid" => "0"],
        "groups" => ["groupname" => "wheel"]
      }
      expect(Yast::WFM).to receive(:CallFunction).with("users_auto", ["Import", expected_data])

      subject.import_sections
    end

    it "handles description with aliased section" do
      expect(Yast::WFM).to receive(:CallFunction).with("services-manager_auto", ["Import", {}])

      subject.import_sections
    end
  end

  describe "#import_entry" do
    let(:profile) do
      {
        "users"      => ["username" => "root", "uid" => "0"],
        "groups"     => ["groupname" => "wheel"],
        "bootloader" => {},
        "runlevel"   => {},
        "scripts"    => {}
      }
    end

    let(:success?) { true }

    before do
      allow(Yast::WFM).to receive(:CallFunction).and_return(success?)
    end

    it "accepts string or Description parameter" do
      expect(Yast::WFM).to receive(:CallFunction).with("bootloader_auto", ["Import", {}]).twice

      subject.import_entry(registry.descriptions.find { |d| d.module_name == "bootloader" })
      subject.import_entry("bootloader")
    end

    it "import section without description for string parameter" do
      expect(Yast::WFM).to receive(:CallFunction).with("scripts_auto", ["Import", {}])

      subject.import_entry("scripts")
    end

    it "supports aliased description" do
      expect(Yast::WFM).to receive(:CallFunction).with("services-manager_auto", ["Import", {}])

      subject.import_entry("services-manager")
    end

    it "supports multiple sections description" do
      expected_data = {
        "users"  => ["username" => "root", "uid" => "0"],
        "groups" => ["groupname" => "wheel"]
      }
      expect(Yast::WFM).to receive(:CallFunction).with("users_auto", ["Import", expected_data])

      subject.import_entry("users")
    end

    it "returns a result containing all imported keys" do
      result = subject.import_entry("users")
      expect(result.sections).to match_array(["users", "groups"])
    end

    context "when the call to the auto client works" do
      it "returns a successful result" do
        result = subject.import_entry("bootloader")
        expect(result).to be_success
      end
    end

    context "when the call to the auto client returns nothing" do
      let(:success?) { nil }

      it "returns a successful result" do
        result = subject.import_entry("bootloader")
        expect(result).to be_success
      end
    end

    context "when the call to the auto client fails" do
      let(:success?)  { false }

      it "the contains a failing result" do
        result = subject.import_entry("bootloader")
        expect(result).to_not be_success
      end
    end
  end
end
