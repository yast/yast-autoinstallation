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
require "autoinstall/widgets/ask/password_field"
require "autoinstall/ask/question"
require "cwm/rspec"

describe Y2Autoinstall::Widgets::Ask::PasswordField do
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
