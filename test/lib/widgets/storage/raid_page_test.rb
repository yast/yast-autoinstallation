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
require "autoinstall/presenters"
require "autoinstall/widgets/storage/raid_page"
require "y2storage/autoinst_profile"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::RaidPage do
  subject { described_class.new(drive) }

  include_examples "CWM::Page"

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
      [{ "device" => "/dev/md0", "type" => :CT_RAID }]
    )
  end
  let(:drive) { Y2Autoinstallation::Presenters::Drive.new(partitioning.drives.first) }

  let(:raid_name_widget) do
    instance_double(
      Y2Autoinstallation::Widgets::Storage::RaidName,
      value: "/dev/md1"
    )
  end

  before do
    allow(Y2Autoinstallation::Widgets::Storage::RaidName)
      .to receive(:new).and_return(raid_name_widget)
  end

  describe "#init" do
    it "sets the widget initial values" do
      expect(raid_name_widget).to receive(:value=).with("/dev/md0")
      subject.init
    end
  end
end
