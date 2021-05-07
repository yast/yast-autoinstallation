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
require "autoinstall/script"
require "tmpdir"

describe Y2Autoinstall::Ask::Runner do
  subject(:runner) { described_class.new(profile, stage: :initial) }

  let(:profile) do
    Yast::ProfileHash.new(
      "general" => { "ask-list" => ask_list },
      "users"   => [{ "username" => "root", "user_password" => "ask" }]
    )
  end

  let(:ask_list) do
    [
      { "dialog" => 1, "question" => "Question 1" }
    ]
  end

  let(:dialogs) { [dialog1] }

  let(:profile_reader) do
    instance_double(Y2Autoinstall::Ask::ProfileReader, dialogs: dialogs)
  end

  let(:dialog1) do
    Y2Autoinstall::Ask::Dialog.new(1, [question1])
  end

  let(:question1) do
    Y2Autoinstall::Ask::Question.new("Question 1")
  end

  let(:ask_dialog1) do
    instance_double(Y2Autoinstall::Widgets::AskDialog, run: :next)
  end

  describe "#run" do
    before do
      allow(Y2Autoinstall::Ask::ProfileReader).to receive(:new)
        .and_return(profile_reader)
      allow(Y2Autoinstall::Widgets::AskDialog).to receive(:new)
        .with(dialog1, disable_back_button: true).and_return(ask_dialog1)
    end

    context "when :initial stage is given" do
      it "runs the dialogs from the :initial stage" do
        expect(Y2Autoinstall::Ask::ProfileReader).to receive(:new)
          .with(Y2Autoinstall::AutoinstProfile::AskListSection, stage: :initial)
          .and_return(profile_reader)
        runner.run
      end
    end

    context "when :cont stage is given" do
      subject(:runner) { described_class.new(profile, stage: :cont) }

      it "runs the dialogs from the :cont stage" do
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
      let(:script) do
        instance_double(Y2Autoinstallation::AskScript, environment: environment?)
      end

      let(:script_runner) do
        instance_double(Y2Autoinstall::ScriptRunner)
      end

      let(:environment?) { false }

      let(:question1) do
        Y2Autoinstall::Ask::Question.new("Question 1").tap do |question|
          question.script = script
          question.value = "value"
        end
      end

      before do
        allow(Y2Autoinstall::ScriptRunner).to receive(:new).and_return(script_runner)
      end

      it "runs the given script" do
        expect(script).to receive(:create_script_file)
        expect(script_runner).to receive(:run).with(script, env: {})
        runner.run
      end

      context "when the 'environment' attribute is set to 'true'" do
        let(:environment?) { true }

        it "passes the question value to the script" do
          expect(script).to receive(:create_script_file)
          expect(script_runner).to receive(:run).with(script, env: { "VAL" => question1.value })
          runner.run
        end
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

    context "when a /tmp/next_dialog exists" do
      let(:dialogs) { [dialog1, dialog2] }

      let(:dialog2) do
        Y2Autoinstall::Ask::Dialog.new(2, [question2])
      end

      let(:question2) do
        Y2Autoinstall::Ask::Question.new("Question 2")
      end

      let(:ask_dialog2) do
        instance_double(Y2Autoinstall::Widgets::AskDialog, run: :next)
      end

      let(:tmp_dir) { Dir.mktmpdir }
      let(:next_dialog_file) { File.join(tmp_dir, "next_dialog") }

      before do
        stub_const("Y2Autoinstall::Ask::Runner::DIALOG_FILE", next_dialog_file)
        allow(Y2Autoinstall::Widgets::AskDialog).to receive(:new)
          .with(dialog2, any_args).and_return(ask_dialog2)
      end

      after do
        FileUtils.remove_entry(tmp_dir) if Dir.exist?(tmp_dir)
      end

      context "and it is a regular file" do
        before do
          File.write(next_dialog_file, "2\n")
        end

        it "jumps to the dialog specified in the file" do
          expect(ask_dialog1).to_not receive(:run)
          expect(ask_dialog2).to receive(:run)
          runner.run
        end
      end

      context "but it is not a regular file" do
        let(:linked_file) { File.join(tmp_dir, "some-file") }

        before do
          FileUtils.ln_s(linked_file, next_dialog_file)
        end

        it "ignores the content and goes to the following dialog" do
          expect(ask_dialog1).to receive(:run)
          expect(ask_dialog2).to receive(:run)
          runner.run
        end
      end

      context "but it too big" do
        before do
          allow(File).to receive(:size).with(next_dialog_file).and_return(2048)
        end

        it "ignores the content and goes to the following dialog" do
          expect(ask_dialog1).to receive(:run)
          expect(ask_dialog2).to receive(:run)
          runner.run
        end
      end
    end
  end
end
