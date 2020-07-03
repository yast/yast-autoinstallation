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

require_relative "../../test_helper"
require "autoinstall/entries/registry"

describe Y2Autoinstallation::Entries::Registry do
  subject { described_class.instance }

  let(:module_map) do
    path = File.expand_path("../../fixtures/desktop_files/desktops.yml", __dir__)
    YAML.safe_load(File.read(path))
  end

  let(:groups) do
    path = File.expand_path("../../fixtures/desktop_files/groups.yml", __dir__)
    YAML.safe_load(File.read(path))
  end

  before do
    # reset singleton
    allow(Yast::Desktop).to receive(:Modules)
      .and_return(module_map)
    allow(Yast::Desktop).to receive(:Groups)
      .and_return(module_map)
    reset_singleton(Y2Autoinstallation::Entries::Registry)
  end

  describe "#descriptions" do
    it "returns list of descriptions" do
      expect(subject.descriptions).to be_all(Y2Autoinstallation::Entries::Description)
    end
  end

  describe "#confirable_descriptios" do
    it "returns list of descriptions which can be configured" do
      descriptions = subject.configurable_descriptions
      expect(descriptions).to_not be_empty

      descriptions.each { |d| expect(d.mode).to eq("all").or eq("configure") }
    end
  end

  describe "#writable_descriptios" do
    it "returns list of descriptions which can be written" do
      descriptions = subject.writable_descriptions
      expect(descriptions).to_not be_empty

      descriptions.each { |d| expect(d.mode).to eq("all").or eq("write") }
    end
  end

  describe "#groups" do
    it "returns hash with group name as key and its attributes as value" do
      expect(subject.groups).to be_a(Hash)
      expect(subject.groups.keys).to be_all(String)
      expect(subject.groups.values).to be_all(Hash)
    end
  end
end
