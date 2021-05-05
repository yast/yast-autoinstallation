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
require "autoinstall/ask/dialog"
require "autoinstall/ask/question"
require "autoinstall/autoinst_profile/ask_section"

describe Y2Autoinstall::Ask::Runner do
  subject(:runner) { described_class.new(profile) }

  let(:profile) do
    { "general" => { "ask-list" => ask_list } }
  end

  let(:ask_list) do
    [
      { "dialog" => 1, "question" => "Question 1" }
    ]
  end

  let(:dialogs) { [initial_dialog, cont_dialog] }

  let(:profile_reader) do
    instance_double(Y2Autoinstall::Ask::ProfileReader, dialogs: dialogs)
  end

  let(:initial_dialog) do
    Y2Autoinstall::Ask::Dialog.new(1, [question1])
  end

  let(:cont_dialog) do
    Y2Autoinstall::Ask::Dialog.new(2, [question2])
  end

  let(:question1) do
    Y2Autoinstall::Ask::Question.new("Question 1")
  end

  let(:question2) do
    Y2Autoinstall::Ask::Question.new("Question 2").tap { |q| q.stage = :cont }
  end

  let(:ask_dialog1) do
    instance_double(Y2Autoinstall::Widgets::AskDialog, run: :next)
  end

  describe "#run" do
    before do
      allow(Y2Autoinstall::Ask::ProfileReader).to receive(:new)
        .and_return(profile_reader)
    end

    it "runs the dialogs from the given stage" do
      expect(Y2Autoinstall::Widgets::AskDialog).to receive(:new)
        .with(initial_dialog, stage: :initial, disable_back_button: true)
        .and_return(ask_dialog1)
      runner.run
    end
  end
end
