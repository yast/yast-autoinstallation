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
require "autoinstall/ask/profile_reader"
require "autoinstall/autoinst_profile/ask_section"
require "autoinstall/autoinst_profile/ask_list_section"

describe Y2Autoinstall::Ask::ProfileReader do
  subject(:reader) { described_class.new(ask_list) }

  let(:section0) do
    Y2Autoinstall::AutoinstProfile::AskSection.new_from_hashes(
      "question" => "Question 1",
      "dialog"   => 1
    )
  end

  let(:ask_list) do
    Y2Autoinstall::AutoinstProfile::AskListSection.new.tap do |l|
      l.entries = sections
    end
  end

  let(:sections) { [section0] }

  describe "#dialogs" do
    it "returns an array containing the dialogs" do
      dialog = reader.dialogs.first

      question = dialog.questions.first
      expect(question.text).to eq("Question 1")
      expect(dialog.id).to eq(1)
    end

    context "when two questions has the same dialog number" do
      let(:section0) do
        Y2Autoinstall::AutoinstProfile::AskSection.new_from_hashes(
          "question"   => "Question 1",
          "dialog"     => 1,
          "element"    => 1,
          "width"      => 240,
          "height"     => 120,
          "ok_label"   => "N",
          "back_label" => "B",
          "timeout"    => 10,
          "title"      => "Title #1"
        )
      end

      let(:section1) do
        Y2Autoinstall::AutoinstProfile::AskSection.new_from_hashes(
          "question"   => "Question 2",
          "dialog"     => 1,
          "element"    => 2,
          "width"      => 320,
          "height"     => 240,
          "ok_label"   => "Next",
          "back_label" => "Back",
          "timeout"    => 20,
          "title"      => "Title #2"
        )
      end

      let(:sections) { [section1, section0] }

      it "groups them into the same dialog" do
        dialogs = reader.dialogs
        expect(dialogs.size).to eq(1)
        texts = dialogs.first.questions.map(&:text)
        expect(texts).to eq(["Question 1", "Question 2"])
      end

      it "uses width, height, labels, timeout and title from the last question" do
        dialog = reader.dialogs.first
        expect(dialog.width).to eq(320)
        expect(dialog.height).to eq(240)
        expect(dialog.ok_label).to eq("Next")
        expect(dialog.back_label).to eq("Back")
        expect(dialog.title).to eq("Title #2")
        expect(dialog.timeout).to eq(20)
      end
    end

    context "stage selection" do
      let(:initial0) do
        Y2Autoinstall::AutoinstProfile::AskSection.new_from_hashes(
          "question" => "Question 1",
          "dialog"   => 1
        )
      end

      let(:initial1) do
        Y2Autoinstall::AutoinstProfile::AskSection.new_from_hashes(
          "question" => "Question 2",
          "dialog"   => 1,
          "stage"    => "initial"
        )
      end

      let(:cont0) do
        Y2Autoinstall::AutoinstProfile::AskSection.new_from_hashes(
          "question" => "Question 3",
          "dialog"   => 1,
          "stage"    => "cont"
        )
      end

      let(:sections) { [initial0, initial1, cont0] }

      context "when a stage is set" do
        subject(:reader) { described_class.new(ask_list, stage: Y2Autoinstall::Ask::Stage::CONT) }

        it "includes questions for the given stage" do
          dialogs = reader.dialogs
          expect(dialogs.size).to eq(1)
          texts = dialogs.first.questions.map(&:text)
          expect(texts).to eq(["Question 3"])
        end
      end

      context "when no stage is set" do
        subject(:reader) { described_class.new(ask_list) }

        it "includes questions for the initial stage" do
          dialogs = reader.dialogs
          expect(dialogs.size).to eq(1)
          texts = dialogs.first.questions.map(&:text)
          expect(texts).to eq(["Question 1", "Question 2"])
        end
      end
    end

    context "when an <ask> section does not specify a dialog" do
      let(:sections) { [section_no_id0, section_no_id1, section1] }

      let(:section1) do
        Y2Autoinstall::AutoinstProfile::AskSection.new_from_hashes(
          "question" => "Question 3",
          "dialog"   => 1
        )
      end

      let(:section_no_id0) do
        Y2Autoinstall::AutoinstProfile::AskSection.new_from_hashes(
          "question" => "Question 1",
          "element"  => 2
        )
      end

      let(:section_no_id1) do
        Y2Autoinstall::AutoinstProfile::AskSection.new_from_hashes(
          "question" => "Question 2",
          "element"  => 1
        )
      end

      it "returns a separate dialog for each of those sections" do
        dialogs = reader.dialogs
        expect(dialogs.size).to eq(3)
      end

      it "respects the order in which they were declared" do
        dialogs = reader.dialogs
        texts = dialogs.map(&:questions).flatten.map(&:text)
        expect(texts).to eq(
          ["Question 1", "Question 2", "Question 3"]
        )
      end
    end

    context "when the <ask> section includes a script" do
      let(:section0) do
        Y2Autoinstall::AutoinstProfile::AskSection.new_from_hashes(
          "question" => "Question 1",
          "script"   => { "source" => "touch /tmp/result" }
        )
      end

      it "creates an AskScript object" do
        dialog = reader.dialogs.first
        question = dialog.questions.first
        script = question.script
        expect(script.source).to eq(section0.script.source)
      end
    end

    context "when the <ask> section includes a script to get the default value" do
      let(:section0) do
        Y2Autoinstall::AutoinstProfile::AskSection.new_from_hashes(
          "question"             => "Question 1",
          "default_value_script" => { "source" => "touch /tmp/result" }
        )
      end

      it "creates an AskScript object" do
        dialog = reader.dialogs.first
        question = dialog.questions.first
        script = question.default_value_script
        expect(script.source).to eq(section0.default_value_script.source)
      end
    end
  end
end
