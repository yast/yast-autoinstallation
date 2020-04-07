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
require "autoinstall/widgets/storage/disk_page"
require "y2storage"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::DiskPage do
  subject { described_class.new(drive) }

  let(:drive) { Y2Storage::AutoinstProfile::DriveSection.new_from_hashes({}) }

  include_examples "CWM::Page"

  describe "#label" do
    before { drive.device = device }

    context "when the partition device is defined" do
      let(:device) { "/dev/sda" }

      it "includes the device" do
        expect(subject.label).to include("/dev/sda")
      end
    end

    context "when the partition device is not defined" do
      let(:device) { "" }

      it "does not include the device" do
        expect(subject.label).to eq("Disk")
      end
    end
  end

  describe "#store" do
    let(:disk_device_widget) do
      instance_double(
        Y2Autoinstallation::Widgets::Storage::DiskDevice,
        value: "/dev/sdb"
      )
    end

    before do
      allow(Y2Autoinstallation::Widgets::Storage::DiskDevice)
        .to receive(:new).and_return(disk_device_widget)
    end

    it "sets the section values" do
      subject.store
      expect(drive.device).to eq("/dev/sdb")
    end
  end
end
