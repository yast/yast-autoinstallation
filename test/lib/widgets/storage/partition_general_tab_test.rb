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
require "autoinstall/widgets/storage/partition_general_tab"
require "autoinstall/presenters"
require "y2storage/autoinst_profile"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::PartitionGeneralTab do
  subject { described_class.new(partition) }

  include_examples "CWM::Page"

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(
      [{ "type" => type, "partitions" => [partition_hash] }]
    )
  end
  let(:type) { :CT_DISK }
  let(:drive) { Y2Autoinstallation::Presenters::Drive.new(partitioning.drives.first) }
  let(:partition) { drive.partitions.first }
  let(:partition_hash) { {} }

  describe "#contents" do
    it "constains a widget to fill the size" do
      widget = subject.contents.nested_find do |w|
        w.is_a?(Y2Autoinstallation::Widgets::Storage::SizeSelector)
      end

      expect(widget).to_not be_nil
    end

    context "when the partition belongs to an LVM" do
      let(:type) { :CT_LVM }

      it "contains LVM partition attributes" do
        widget = subject.contents.nested_find do |w|
          w.is_a?(Y2Autoinstallation::Widgets::Storage::LvmPartitionAttrs)
        end

        expect(widget).to_not be_nil
      end
    end
  end

  describe "#store" do
    it "sets the partition section attributes" do
      expect(partition).to receive(:update)
      subject.store
    end
  end
end
