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

require "autoinstall/script"

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
