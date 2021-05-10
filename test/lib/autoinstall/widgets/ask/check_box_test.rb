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
require "autoinstall/widgets/ask/check_box"
require "autoinstall/ask/question"
require "autoinstall/script"
require "cwm/rspec"

describe Y2Autoinstall::Widgets::Ask::CheckBox do
  subject { described_class.new(question) }

  let(:question) do
    Y2Autoinstall::Ask::Question.new("Question 1").tap do |question|
      question.type = "boolean"
    end
  end

  include_examples "CWM::CheckBox"
  include_examples "ask dialog widget"

  describe "#init" do
    before do
      question.default = false
    end

    context "when the question has a value" do
      before do
        question.value = true
      end

      it "sets widget's value" do
        expect(subject).to receive(:value=).with(true)
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
        let(:stdout) { "true" }

        before do
          question.default_value_script = script
        end

        context "and the script returns 'true'" do
          it "sets the value to true" do
            expect(subject).to receive(:value=).with(true)
            subject.init
          end
        end

        context "and the script does not return 'true'" do
          let(:stdout) { "no" }

          it "sets the value to false" do
            expect(subject).to receive(:value=).with(false)
            subject.init
          end
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
