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
require "autoinstall/widgets/storage/drive_page"
require "autoinstall/presenters"
require "y2storage/autoinst_profile"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::DrivePage do
  subject(:drive_page) { described_class.new(drive) }

  include_examples "CWM::Page"

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
      [{ "type" => :CT_DISK, "enable_snapshots" => true }]
    )
  end
  let(:drive) { Y2Autoinstallation::Presenters::Drive.new(partitioning.drives.first) }

  let(:enable_snapshots_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::EnableSnapshots, value: false)
  end

  before do
    allow(Y2Autoinstallation::Widgets::Storage::EnableSnapshots)
      .to receive(:new).and_return(enable_snapshots_widget)
  end

  include_examples "CWM::Page"

  describe "#init" do
    it "initializes enable_snapshots attribute" do
      expect(enable_snapshots_widget).to receive(:value=).with(true)

      drive_page.init
    end
  end

  describe "#store" do
    it "sets the enable_snapshots value" do
      subject.store

      expect(drive.enable_snapshots).to eq(false)
    end
  end
end
