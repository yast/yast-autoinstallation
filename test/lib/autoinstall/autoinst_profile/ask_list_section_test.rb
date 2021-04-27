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
require "autoinstall/autoinst_profile/ask_list_section"

describe Y2Autoinstall::AutoinstProfile::AskListSection do
  describe ".new_from_hashes" do
    it "returns an instance containing the <ask> entries" do
      section = described_class.new_from_hashes(
        [{ "question" => "Question 1" }, { "question" => "Question 2" }]
      )

      expect(section.entries.map(&:question)).to eq(["Question 1", "Question 2"])
    end
  end
end
