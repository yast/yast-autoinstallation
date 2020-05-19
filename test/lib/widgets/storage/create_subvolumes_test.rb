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

require_relative "../../../test_helper"
require_relative "./shared_examples"
require "autoinstall/widgets/storage/create_subvolumes"

describe Y2Autoinstallation::Widgets::Storage::CreateSubvolumes do
  subject(:widget) { described_class.new }

  include_examples "Y2Autoinstallation::Widgets::Storage::BooleanSelector"

  describe "#include_blank?" do
    it "returns true" do
      expect(subject.include_blank?).to eq(true)
    end
  end
end
