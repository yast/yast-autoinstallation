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
    it "contains common partition attributes" do
      widget = subject.contents.nested_find do |w|
        w.is_a?(Y2Autoinstallation::Widgets::Storage::CommonPartitionAttrs)
      end

      expect(widget).to_not be_nil
    end

    context "when the partition belongs to a disk" do
      let(:type) { :CT_DISK }

      it "does not contain LVM partition attributes" do
        widget = subject.contents.nested_find do |w|
          w.is_a?(Y2Autoinstallation::Widgets::Storage::LvmPartitionAttrs)
        end

        expect(widget).to be_nil
      end
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
    let(:common_attributes) do
      {
        "create"       => true,
        "format"       => true,
        "resize"       => false,
        "size"         => "10G",
        "partition_nr" => 2,
        "uuid"         => "partition-uuid"
      }
    end

    let(:lv_attributes) do
      {
        "lv_name"     => "lv-home",
        "pool"        => false,
        "used_pool"   => "my_thin_pool",
        "stripes"     => 2,
        "stripe_size" => 4
      }
    end

    let(:common_attrs_widget) do
      instance_double(
        Y2Autoinstallation::Widgets::Storage::CommonPartitionAttrs,
        values: common_attributes
      )
    end
    let(:lvm_attrs_widget) do
      instance_double(
        Y2Autoinstallation::Widgets::Storage::LvmPartitionAttrs,
        values: lv_attributes
      )
    end

    before do
      allow(Y2Autoinstallation::Widgets::Storage::CommonPartitionAttrs).to receive(:new)
        .and_return(common_attrs_widget)
      allow(Y2Autoinstallation::Widgets::Storage::LvmPartitionAttrs).to receive(:new)
        .and_return(lvm_attrs_widget)
    end

    it "sets section attributes not related to its usage" do
      subject.store

      expect(partition.create).to eq(true)
      expect(partition.format).to eq(true)
      expect(partition.resize).to eq(false)
      expect(partition.size).to eq("10G")
      expect(partition.partition_nr).to eq(2)
      expect(partition.uuid).to eq("partition-uuid")

      expect(partition.lv_name).to eq("lv-home")
      expect(partition.pool).to eq(false)
      expect(partition.used_pool).to eq("my_thin_pool")
      expect(partition.stripes).to eq(2)
      expect(partition.stripe_size).to eq(4)
    end
  end
end
