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

require_relative "../../../test_helper"
require "autoinstall/autoinst_profile/ask_section"

describe Y2Autoinstall::AutoinstProfile::AskSection do
  describe ".new_from_hashes" do
    let(:hash) do
      {
        "question" => "Username",
        "title"    => "User",
        "help"     => "Username of the first user",
        "pathlist" => ["users,1,username"]
      }
    end

    it "returns an AskSection with the given attributes" do
      section = described_class.new_from_hashes(hash)

      expect(section.question).to eq("Username")
      expect(section.title).to eq("User")
      expect(section.pathlist).to eq(["users,1,username"])
    end

    context "when there are not selection options" do
      it "sets 'selection' to nil" do
        section = described_class.new_from_hashes(hash)

        expect(section.selection).to be_nil
      end
    end

    context "when selection options are included" do
      let(:hash) do
        {
          "question"  => "Username",
          "selection" => [{ "label" => "Option 1", "value" => "opt1" }]
        }
      end

      it "sets 'selection' to an array of AskSelectionEntry objects" do
        section = described_class.new_from_hashes(hash)

        expect(section.selection).to be_a(Array)
        option = section.selection.first
        expect(option.label).to eq("Option 1")
        expect(option.value).to eq("opt1")
      end
    end

    context "when a default value script is included" do
      let(:hash) do
        {
          "question" => "Username",
          "default_value_script" => { "source" => "touch /tmp/test" }
        }
      end

      it "sets the 'default_value_script' attribute" do
        section = described_class.new_from_hashes(hash)

        expect(section.default_value_script)
          .to be_a(Y2Autoinstall::AutoinstProfile::ScriptSection)
        expect(section.default_value_script.source)
          .to eq(hash["default_value_script"]["source"])
      end
    end

    context "when a script is included" do
      let(:hash) do
        {
          "question" => "Username",
          "script" => { "source" => "touch /tmp/test" }
        }
      end

      it "sets the 'script' attribute" do
        section = described_class.new_from_hashes(hash)

        expect(section.script).to be_a(Y2Autoinstall::AutoinstProfile::ScriptSection)
        expect(section.script.source).to eq(hash["script"]["source"])
      end
    end
  end
end
