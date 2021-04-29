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
require "autoinstall/ask/runner"
require "autoinstall/autoinst_profile/ask_section"

describe Y2Autoinstall::Ask::Runner do
  subject(:runner) { described_class.new(profile) }

  let(:profile) do
    { "general" => { "ask-list" => ask_list } }
  end

  let(:ask_list) do
    [{ "dialog" => 1, "question" => "Question 1" }]
  end

  let(:ask_dialog1) do
    instance_double(Y2Autoinstall::Widgets::AskDialog, run: :next)
  end

  describe "#run" do
    before do
      allow(Y2Autoinstall::Widgets::AskDialog).to receive(:new)
        .and_return(ask_dialog1)
    end

    it "just runs" do
      expect(ask_dialog1).to receive(:run).and_return(:next)
      runner.run
    end
  end
end
