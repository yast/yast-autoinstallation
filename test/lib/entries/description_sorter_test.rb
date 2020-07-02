# Copyright (c) [2020] SUSE LLC
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

require_relative "../../test_helper"
require "autoinstall/entries/description_sorter"
require "autoinstall/entries/description"

describe Y2Autoinstallation::Entries::DescriptionSorter do
  subject { described_class.new(descriptions) }

  let(:descriptions) { [] }
  let(:description1) do
    Y2Autoinstallation::Entries::Description.new(
      { "X-SuSE-YaST-AutoInstRequires" => "" }, "description1"
    )
  end
  let(:description2) { Y2Autoinstallation::Entries::Description.new({}, "description2") }
  let(:description3) do
    Y2Autoinstallation::Entries::Description.new(
      { "X-SuSE-YaST-AutoInstRequires" => "description1" }, "description3"
    )
  end
  let(:description4) do
    Y2Autoinstallation::Entries::Description.new(
      { "X-SuSE-YaST-AutoInstRequires" => "description1, description3" }, "description4"
    )
  end

  describe "#sort" do
    context "there are no descriptions" do
      it "returns empty array" do
        expect(subject.sort).to eq []
      end
    end

    context "there are no dependencies" do
      let(:descriptions) { [description1, description2] }
      it "returns descriptions in random order" do
        expect(subject.sort).to match_array(descriptions)
      end
    end

    context "there are dependencies" do
      let(:descriptions) { [description1, description4, description3] }
      it "returns sorter array" do
        expect(subject.sort).to eq([description1, description3, description4])
      end
    end
  end
end
