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

describe Y2Autoinstall::Ask::Question do
  describe ".new" do
    it "returns an instance with the given text" do
      question = described_class.new("Question 1")
      expect(question.text).to eq("Question 1")
    end
  end

  describe "#value=" do
    subject(:question) do
      described_class.new("Question 1").tap { |q| q.type = type }
    end

    context "when the question's type is an integer" do
      let(:type) { "integer" }

      it "sets the value as 'integer'" do
        question.value = "1"
        expect(question.value).to eq(1)
      end
    end

    context "when the question's type is 'boolean'" do
      let(:type) { "boolean" }

      it "sets the value as a boolean" do
        question.value = true
        expect(question.value).to eq(true)
      end

      context "when the value is 'true'" do
        it "sets the value to 'true'" do
          question.value = "true"
          expect(question.value).to eq(true)
        end
      end

      context "when the value is not true" do
        it "sets the value to false" do
          question.value = "false"
          expect(question.value).to eq(false)
        end
      end
    end

    context "when the question's type is 'symbol'" do
      let(:type) { "symbol" }

      it "sets the value as an integer" do
        question.value = "sym"
        expect(question.value).to eq(:sym)
      end
    end

    context "when the question's type is 'string'" do
      let(:type) { "string" }

      it "sets the value as an string" do
        question.value = "1"
        expect(question.value).to eq("1")
      end
    end

    context "when the question's type is 'static_text'" do
      let(:type) { "static_text" }

      it "does not set the value" do
        question.value = "1"
        expect(question.value).to be_nil
      end
    end

    context "when the question's type is not set" do
      subject(:question) do
        described_class.new("Question 1")
      end

      it "sets the value as an string" do
        question.value = "1"
        expect(question.value).to eq("1")
      end
    end
  end
end
