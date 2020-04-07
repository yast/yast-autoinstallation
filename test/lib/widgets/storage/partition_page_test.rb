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
require "autoinstall/widgets/storage/partition_page"
require "y2storage"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::PartitionPage do
  subject { described_class.new(partition) }
  let(:partition) { Y2Storage::AutoinstProfile::PartitionSection.new_from_hashes({}) }

  include_examples "CWM::Page"

  describe "#label" do
    before { partition.mount = mount }

    context "when the partition mount point is defined" do
      let(:mount) { "/opt" }

      it "includes the mount point" do
        expect(subject.label).to include("/opt")
      end
    end

    context "when the partition mount point is not defined" do
      let(:mount) { "" }

      it "does not include the mount point" do
        expect(subject.label).to eq("Partition")
      end
    end
  end

  describe "#store" do
    let(:mount_point_widget) do
      instance_double(
        Y2Autoinstallation::Widgets::Storage::MountPoint,
        value: "/boot"
      )
    end

    before do
      allow(Y2Autoinstallation::Widgets::Storage::MountPoint)
        .to receive(:new).and_return(mount_point_widget)
    end

    it "sets the section values" do
      subject.store
      expect(partition.mount).to eq("/boot")
    end
  end
end
