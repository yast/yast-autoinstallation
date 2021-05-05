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
require "autoinstall/ask/question"
require "autoinstall/ask/dialog"

describe Y2Autoinstall::Ask::Dialog do
  describe "#update" do
    describe ".new" do
      let(:question1) do
        Y2Autoinstall::Ask::Question.new("Question 1")
      end

      it "returns a dialog with the given id and the list of questions" do
        dialog = described_class.new(1, [question1])
        expect(dialog.id).to eq(1)
        expect(dialog.questions).to eq([question1])
      end
    end
  end
end
