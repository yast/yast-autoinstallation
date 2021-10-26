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
require "autoinstall/autoinst_profile/script_section"

describe Y2Autoinstall::AutoinstProfile::ScriptSection do
  describe ".new_from_hashes" do
    let(:hash) do
      { "filename"    => "script.sh",
        "environment" => true }
    end

    it "returns an ScriptSection with the given attributes" do
      section = described_class.new_from_hashes(hash)

      expect(section.filename).to eq("script.sh")
      expect(section.environment).to eq(true)
    end
  end
end
