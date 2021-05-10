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
require "autoinstall/widgets/ask/combo_box"
require "autoinstall/ask/question"
require "autoinstall/ask/question_option"
require "cwm/rspec"

describe Y2Autoinstall::Widgets::Ask::ComboBox do
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
