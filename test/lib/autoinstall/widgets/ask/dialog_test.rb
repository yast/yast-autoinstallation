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

require_relative "../../../../test_helper"
require "autoinstall/widgets/ask/dialog"
require "autoinstall/ask/dialog"
require "autoinstall/ask/question"
require "autoinstall/ask/question_option"
require "autoinstall/script"
require "cwm/rspec"

describe Y2Autoinstall::Widgets::Ask::Dialog do
  # Helper to get dialog widgets getting rid of alignment widgets (e.g., Left())
  #
  # @param parent [CWM::AbstractWidget]
  def widgets_from(parent)
    parent.widgets.map(&:params).flatten
  end

  subject { described_class.new(dialog) }

  let(:dialog) { Y2Autoinstall::Ask::Dialog.new(1, []) }

  describe "#contents" do
    let(:dialog) { Y2Autoinstall::Ask::Dialog.new(1, [question]) }
    let(:question) do
      Y2Autoinstall::Ask::Question.new("Question 1")
    end

    context "when the dialog includes a text field" do
      it "includes an input field" do
        widget = widgets_from(subject.contents).first
        expect(widget).to be_a(Y2Autoinstall::Widgets::Ask::InputField)
        expect(widget.label).to eq("Question 1")
      end
    end

    context "when the dialog includes a password field" do
      let(:question) do
        Y2Autoinstall::Ask::Question.new("Question 1").tap { |q| q.password = true }
      end

      it "includes a password field" do
        widget = widgets_from(subject.contents).first
        expect(widget).to be_a(Y2Autoinstall::Widgets::Ask::PasswordField)
        expect(widget.label).to eq("Question 1")
      end
    end

    context "when the dialog includes a boolean question" do
      let(:question) do
        Y2Autoinstall::Ask::Question.new("Question 1").tap do |q|
          q.type = "boolean"
        end
      end

      it "includes a checkbox" do
        widget = widgets_from(subject.contents).first
        expect(widget).to be_a(Y2Autoinstall::Widgets::Ask::CheckBox)
        expect(widget.label).to eq("Question 1")
      end
    end

    context "when the dialog includes an static text" do
      let(:question) do
        Y2Autoinstall::Ask::Question.new("Question 1").tap do |q|
          q.default = "Question 1"
          q.type = "static_text"
        end
      end

      it "includes a label" do
        widget = widgets_from(subject.contents).first
        expect(widget.value).to eq(:Label)
        _id, text = widget.to_a
        expect(text).to eq("Question 1")
      end
    end

    context "when the question includes a symbol field" do
      let(:question) do
        Y2Autoinstall::Ask::Question.new("Question 1").tap do |q|
          q.type = "symbol"
        end
      end

      it "includes a ComboBox" do
        widget = widgets_from(subject.contents).first
        expect(widget).to be_a(Y2Autoinstall::Widgets::Ask::ComboBox)
      end
    end

    context "when the question includes some options to choose from" do
      let(:question) do
        Y2Autoinstall::Ask::Question.new("Question 1").tap do |q|
          q.options = [
            Y2Autoinstall::Ask::QuestionOption.new("opt1", "Option 1"),
            Y2Autoinstall::Ask::QuestionOption.new("opt2", "Option 2")
          ]
        end
      end

      it "includes a ComboBox" do
        widget = widgets_from(subject.contents).first
        expect(widget).to be_a(Y2Autoinstall::Widgets::Ask::ComboBox)
        texts = widget.items.map(&:to_a).map(&:last)
        expect(texts).to eq(["Option 1", "Option 2"])
      end
    end

    context "when a timeout is specified" do
      before do
        dialog.timeout = 2
        allow(Yast::UI).to receive(:WaitForEvent).with(1000).and_return("ID" => :timeout)
      end

      it "updates the timer after each second" do
        expect(Yast::UI).to receive(:WaitForEvent).twice.with(1000).and_return("ID" => :timeout)
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(:counter), :Label, "1")
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(:counter), :Label, "0")
        allow(Yast::UI).to receive(:ChangeWidget).and_call_original
        subject.run
      end

      it "returns :next after the timeout" do
        expect(subject.run).to eq(:next)
      end
    end
  end
end
