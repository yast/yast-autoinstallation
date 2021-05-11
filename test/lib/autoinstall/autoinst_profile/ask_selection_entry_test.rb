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
require "autoinstall/autoinst_profile/ask_selection_entry"

describe Y2Autoinstall::AutoinstProfile::AskSelectionEntry do
  describe ".new_from_hashes" do
    let(:hash) do
      {
        "value" => "opt1",
        "label" => "Option 1"
      }
    end

    it "returns an AskSection with the given attributes" do
      section = described_class.new_from_hashes(hash)

      expect(section.value).to eq("opt1")
      expect(section.label).to eq("Option 1")
    end
  end
end
