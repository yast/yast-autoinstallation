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
require "autoinstall/autoinst_profile/ask_list_section"

describe Y2Autoinstall::Ask::Runner do
  subject(:runner) { described_class.new(profile) }

  let(:profile) do
    {
      "general" => { "ask-list" => ask_list },
      "users"   => [{ "username" => "root", "user_password" => "ask" }]
    }
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
      allow(Y2Autoinstall::Widgets::AskDialog).to receive(:new)
        .and_return(ask_dialog1)
    end

    context "when no stage is given" do
      it "runs the dialogs from the :initial stage" do
        expect(Y2Autoinstall::Ask::ProfileReader).to receive(:new)
          .with(Y2Autoinstall::AutoinstProfile::AskListSection, stage: :initial)
          .and_return(profile_reader)
        runner.run
      end
    end

    context "when a stage is given" do
      subject(:runner) { described_class.new(profile, stage: :cont) }

      it "runs the dialogs from the given stage" do
        expect(Y2Autoinstall::Ask::ProfileReader).to receive(:new)
          .with(Y2Autoinstall::AutoinstProfile::AskListSection, stage: :cont)
          .and_return(profile_reader)
        runner.run
      end
    end

    context "when a profile path is set" do
      let(:question1) do
        Y2Autoinstall::Ask::Question.new("Root Password").tap do |question|
          question.paths << "users,0,user_password"
          question.value = "secret"
        end
      end

      it "updates the profile with the value from the question" do
        runner.run
        expect(profile["users"][0]).to eq("username" => "root", "user_password" => "secret")
      end
    end

    context "when a script is set" do
      let(:script) { instance_double(Y2Autoinstall::AskScript) }

      let(:question1) do
        Y2Autoinstall::Ask::Question.new("Question 1").tap do |question|
          question.script = script
        end
      end

      it "runs the given script" do
        expect(script).to receive(:execute)
        runner.run
      end
    end

    context "when a file is given" do
      let(:script) { instance_double(Y2Autoinstall::AskScript) }

      let(:question1) do
        Y2Autoinstall::Ask::Question.new("MOTD").tap do |question|
          question.file = "/etc/motd"
          question.value = "Welcome!"
        end
      end

      it "writes the value to the given file" do
        expect(File).to receive(:write).with(question1.file, question1.value)
        runner.run
      end
    end
  end
end
