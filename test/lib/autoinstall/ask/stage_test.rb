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
require "autoinstall/ask/stage"

describe Y2Autoinstall::Ask::Stage do
  describe "#from_name" do
    it "returns the stage with the given name" do
      expect(described_class.from_name("initial"))
        .to eq(Y2Autoinstall::Ask::Stage::INITIAL)
    end

    context "when the stage is not known" do
      it "returns nil" do
        expect(described_class.from_name("foo")).to eq(nil)
      end
    end
  end
end
