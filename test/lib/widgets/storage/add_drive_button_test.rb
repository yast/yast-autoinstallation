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
require "autoinstall/widgets/storage/add_drive_button"
require "autoinstall/storage_controller"

describe Y2Autoinstallation::Widgets::Storage::AddDriveButton do
  subject { described_class.new(controller) }

  let(:controller) { Y2Autoinstallation::StorageController.new(partitioning) }
  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes([])
  end

  describe "#handle" do
    context "adding a disk" do
      let(:event) do
        { "ID" => :add_disk }
      end

      it "adds a disk" do
        expect(controller).to receive(:add_drive).with(:disk)
        subject.handle(event)
      end
    end

    context "adding a disk" do
      let(:event) do
        { "ID" => :add_raid }
      end

      it "adds a disk" do
        expect(controller).to receive(:add_drive).with(:raid)
        subject.handle(event)
      end
    end
  end
end
