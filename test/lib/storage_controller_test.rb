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

require_relative "../test_helper"
require "autoinstall/storage_controller"
require "y2storage/autoinst_profile/partitioning_section"

describe Y2Autoinstallation::StorageController do
  subject { described_class.new(partitioning) }

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes([])
  end

  describe "#add" do
    it "adds a new section with the given type" do
      subject.add_drive(:disk)
      new_drive = partitioning.drives.first
      expect(new_drive.type).to eq(:CT_DISK)
    end
  end
end
