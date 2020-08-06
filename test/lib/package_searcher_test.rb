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
require "autoinstall/package_searcher"

describe Y2Autoinstallation::PackagerSearcher do
  subject { described_class.new(sections) }
  before do
    allow(::File).to receive(:exist?).and_return(true)
    allow(::File).to receive(:readlines).and_return([
                                                      "include 'add-on.rnc' # yast2-add-on",
                                                      "include 'audit-laf.rnc' # yast2-audit-laf"
                                                    ])
  end

  describe "#evaluate_via_schema" do
    context "no package belongs to section" do
      let(:sections) { ["nis"] }
      it "returns hash with section and empty array" do
        allow(Yast::SCR).to receive(:Execute).and_return(
          "exit"   => 0,
          "stdout" => "/usr/share/YaST2/schema/autoyast/rng/nis.rng",
          "stderr" => ""
        )

        expect(subject.evaluate_via_schema).to eq("nis" => [])
      end
    end

    context "package belonging to section is already installed" do
      let(:sections) { ["add-on"] }
      it "returns hash with section and empty array" do
        allow(Yast::SCR).to receive(:Execute).and_return(
          "exit"   => 0,
          "stdout" => "/usr/share/YaST2/schema/autoyast/rng/add-on.rng",
          "stderr" => ""
        )

        allow(Yast::PackageSystem).to receive(:Installed).and_return(true)

        expect(subject.evaluate_via_schema).to eq("add-on" => [])
      end
    end

    context "package belonging to section is not installed" do
      let(:sections) { ["audit-laf"] }
      it "returns hash with section and array with package" do
        allow(Yast::SCR).to receive(:Execute).and_return(
          "exit"   => 0,
          "stdout" => "/usr/share/YaST2/schema/autoyast/rng/audit-laf.rng",
          "stderr" => ""
        )

        allow(Yast::PackageSystem).to receive(:Installed).and_return(false)

        expect(subject.evaluate_via_schema).to eq("audit-laf" => ["yast2-audit-laf"])
      end
    end
  end

  describe "#evaluate_via_rpm" do
    let(:packages) do
      [
        Y2Packager::Resolvable.new("kind" => :package,
           "name" => "foo", "source" => 1,
           "version" => "1.0", "arch" => "x86_64", "status" => :selected,
           "deps" => [{ "provides" => "foo" }]),
        Y2Packager::Resolvable.new("kind" => :package,
           "name" => "yast2-users", "source" => 1,
           "version" => "1.0", "arch" => "x86_64", "status" => :selected,
           "deps" => [{ "supplements" => "autoyast(groups,users)" }])
      ]
    end

    before do
      allow(Y2Packager::Resolvable).to receive(:find).with(
        kind: :package
      ).and_return(packages)
    end

    context "no package belongs to section" do
      let(:sections) { ["nis"] }
      it "returns hash with section and nil value" do
        expect(subject.evaluate_via_rpm).to eq("nis" => nil)
      end
    end

    context "package belonging to section is already installed" do
      let(:sections) { ["users"] }
      it "returns hash with section and empty value" do
        allow(Yast::PackageSystem).to receive(:Installed).and_return(true)
        expect(subject.evaluate_via_rpm).to eq("users" => [])
      end
    end

    context "package belonging to section is not installed" do
      let(:sections) { ["users"] }
      it "returns hash with section and array with package" do
        allow(Yast::PackageSystem).to receive(:Installed).and_return(false)
        expect(subject.evaluate_via_rpm).to eq("users" => ["yast2-users"])
      end
    end
  end
end
