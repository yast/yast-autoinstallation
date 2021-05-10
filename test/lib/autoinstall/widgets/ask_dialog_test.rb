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
require "autoinstall/widgets/ask_dialog"
require "autoinstall/ask/dialog"
require "autoinstall/ask/question"
require "autoinstall/ask/question_option"
require "autoinstall/script"
require "cwm/rspec"

describe Y2Autoinstall::Widgets::AskDialog do
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
        expect(widget).to be_a(Y2Autoinstall::Widgets::AskDialog::InputField)
        expect(widget.label).to eq("Question 1")
      end
    end

    context "when the dialog includes a password field" do
      let(:question) do
        Y2Autoinstall::Ask::Question.new("Question 1").tap { |q| q.password = true }
      end

      it "includes a password field" do
        widget = widgets_from(subject.contents).first
        expect(widget).to be_a(Y2Autoinstall::Widgets::AskDialog::PasswordField)
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
        expect(widget).to be_a(Y2Autoinstall::Widgets::AskDialog::CheckBox)
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
        expect(widget).to be_a(Y2Autoinstall::Widgets::AskDialog::ComboBox)
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
        expect(widget).to be_a(Y2Autoinstall::Widgets::AskDialog::ComboBox)
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

shared_examples "ask dialog widget initialization" do
  describe "#init" do
    before do
      question.default = "default-value"
    end

    context "when the question has a value" do
      before do
        question.value = "some-value"
      end

      it "sets widget's value" do
        expect(subject).to receive(:value=).with("some-value")
        subject.init
      end
    end

    context "when the question has not a value" do
      context "and it has a default_value_script" do
        let(:script) do
          instance_double(
            Y2Autoinstallation::AskDefaultValueScript,
            create_script_file: nil, execute: result, stdout: stdout
          )
        end

        let(:result) { true }
        let(:stdout) { "some-value" }

        before do
          question.default_value_script = script
        end

        it "uses the script output as the widget's value" do
          expect(subject).to receive(:value=).with(stdout)
          subject.init
        end

        context "but the script fails" do
          let(:result) { false }

          it "uses the default value" do
            expect(subject).to receive(:value=).with(question.default)
            subject.init
          end
        end
      end

      context "and there is no default_value_script" do
        it "uses the question default value as the widget's value" do
          expect(subject).to receive(:value=).with(question.default)
          subject.init
        end
      end
    end
  end
end

shared_examples "ask dialog widget" do
  describe "#store" do
    before do
      subject.value = "some-value"
    end

    it "sets the question's value" do
      expect(question).to receive(:value=).with(subject.value)
      subject.store
    end
  end

  describe "#label" do
    it "returns the question text" do
      expect(subject.label).to eq(question.text)
    end
  end
end

describe Y2Autoinstall::Widgets::AskDialog::InputField do
  subject { described_class.new(question) }

  let(:question) do
    Y2Autoinstall::Ask::Question.new("Question 1")
  end

  include_examples "CWM::InputField"
  include_examples "ask dialog widget"
  include_examples "ask dialog widget initialization"
end

describe Y2Autoinstall::Widgets::AskDialog::CheckBox do
  subject { described_class.new(question) }

  let(:question) do
    Y2Autoinstall::Ask::Question.new("Question 1").tap do |question|
      question.type = "boolean"
    end
  end

  include_examples "CWM::CheckBox"
  include_examples "ask dialog widget"

  describe "#init"
end

describe Y2Autoinstall::Widgets::AskDialog::ComboBox do
  subject { described_class.new(question) }

  let(:question) do
    Y2Autoinstall::Ask::Question.new("Question 1").tap do |question|
      question.options = [option1, option2]
    end
  end

  let(:option1) { Y2Autoinstall::Ask::QuestionOption.new("dhcp", "Automatic") }
  let(:option2) { Y2Autoinstall::Ask::QuestionOption.new("manual") }

  include_examples "CWM::ComboBox"

  describe "#items" do
    it "returns question options" do
      expect(subject.items).to eq(
        [["dhcp", "Automatic"], ["manual", "manual"]]
      )
    end
  end

  include_examples "ask dialog widget"
  include_examples "ask dialog widget initialization"
end

describe Y2Autoinstall::Widgets::AskDialog::PasswordField do
  subject { described_class.new(question) }

  let(:question) do
    Y2Autoinstall::Ask::Question.new("Question 1").tap do |question|
      question.password = true
    end
  end

  include_examples "CWM::CustomWidget"
  include_examples "ask dialog widget"
  include_examples "ask dialog widget initialization"

  describe "#validate" do
    before do
      allow(subject).to receive(:value).and_return(value)
      allow(subject).to receive(:confirmation_value).and_return(confirmation_value)
    end

    let(:value) { "pass1" }

    context "when passwords match" do
      let(:confirmation_value) { "pass1" }

      it "returns true" do
        expect(subject.validate).to eq(true)
      end
    end

    context "when passwords do not match" do
      let(:confirmation_value) { "pass2" }

      it "reports the problem to the user" do
        expect(Yast::Popup).to receive(:Message).with(/the passwords/)
        subject.validate
      end

      it "sets focus on the first password field" do
        expect(Yast::UI).to receive(:SetFocus).with(Id(subject.widget_id))
        subject.validate
      end

      it "returns false" do
        expect(subject.validate).to eq(false)
      end
    end
  end
end
