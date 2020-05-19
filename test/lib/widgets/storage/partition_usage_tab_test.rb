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
require "autoinstall/widgets/storage/partition_usage_tab"
require "autoinstall/presenters"
require "y2storage/autoinst_profile"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::PartitionUsageTab do
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

  let(:used_as) { :none }
  let(:used_as_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::UsedAs)
  end

  describe "#init" do
    before do
      allow(Y2Autoinstallation::Widgets::Storage::UsedAs).to receive(:new)
        .and_return(used_as_widget)
      allow(used_as_widget).to receive(:value).and_return(used_as)
      allow(used_as_widget).to receive(:value=)
      allow(partition).to receive(:usage).and_return(usage)
    end

    let(:usage) { :raid }

    it "updates the used_as value" do
      expect(used_as_widget).to receive(:value=).with(usage)

      subject.init
    end
  end

  describe "#handle" do
    let(:attrs_replace_point) do
      instance_double(CWM::ReplacePoint)
    end
    let(:encryption_replace_point) do
      instance_double(CWM::ReplacePoint)
    end
    let(:empty_widget) do
      instance_double(CWM::Empty)
    end
    let(:filesystem_attrs_widget) do
      instance_double(Y2Autoinstallation::Widgets::Storage::FilesystemAttrs)
    end
    let(:raid_attrs_widget) do
      instance_double(Y2Autoinstallation::Widgets::Storage::RaidAttrs)
    end
    let(:lvm_pv_attrs_widget) do
      instance_double(Y2Autoinstallation::Widgets::Storage::LvmPvAttrs)
    end

    context "when handling an 'used_as' event" do
      let(:event) { { "ID" => "used_as" } }

      before do
        allow(used_as_widget).to receive(:value).and_return(used_as)
        allow(attrs_replace_point).to receive(:replace)
        allow(encryption_replace_point).to receive(:replace)

        allow(Y2Autoinstallation::Widgets::Storage::UsedAs).to receive(:new)
          .and_return(used_as_widget)
        allow(Y2Autoinstallation::Widgets::Storage::FilesystemAttrs).to receive(:new)
          .and_return(filesystem_attrs_widget)
        allow(Y2Autoinstallation::Widgets::Storage::RaidAttrs).to receive(:new)
          .and_return(raid_attrs_widget)
        allow(Y2Autoinstallation::Widgets::Storage::LvmPvAttrs).to receive(:new)
          .and_return(lvm_pv_attrs_widget)
        allow(CWM::ReplacePoint).to receive(:new).with(id: "attrs", widget: anything)
          .and_return(attrs_replace_point)
        allow(CWM::Empty).to receive(:new)
          .and_return(empty_widget)
      end

      context "and :none has been selected" do
        let(:used_as) { :none }

        it "shows none attributes" do
          expect(attrs_replace_point).to receive(:replace).with(empty_widget)

          subject.handle(event)
        end
      end

      context "and :filesystem has been selected" do
        let(:used_as) { :filesystem }

        it "shows attributes related to filesystem usage" do
          expect(attrs_replace_point).to receive(:replace).with(filesystem_attrs_widget)
          subject.handle(event)
        end
      end

      context "and :raid has been selected" do
        let(:used_as) { :raid }

        it "shows attributes related to RAID usage" do
          expect(attrs_replace_point).to receive(:replace).with(raid_attrs_widget)
          subject.handle(event)
        end
      end

      context "and :lvm_pv has been selected" do
        let(:used_as) { :lvm_pv }

        it "shows attributes related to LVM PV usage" do
          expect(attrs_replace_point).to receive(:replace).with(lvm_pv_attrs_widget)
          subject.handle(event)
        end
      end
    end
  end

  describe "#values" do
    it "contains all section attributes related to its usage" do
      expect(subject.values.keys).to contain_exactly(
        "filesystem",
        "fstab_options",
        "label",
        "lvm_group",
        "mkfs_options",
        "mount",
        "mountby",
        "raid_name",
        "bcache_backing_for",
        "btrfs_name",
        "create_subvolumes"
      )
    end
  end

  describe "#store" do
    let(:filesystem_attrs) do
      {
        "filesystem"    => :ext3,
        "label"         => "mydata",
        "mount"         => "swap",
        "mountby"       => :label,
        "fstab_options" => "ro,noatime,user",
        "mkfs_options"  => "-I 128"
      }
    end

    let(:filesystem_attrs_widget) do
      instance_double(
        Y2Autoinstallation::Widgets::Storage::FilesystemAttrs,
        values: filesystem_attrs
      )
    end

    before do
      allow(Y2Autoinstallation::Widgets::Storage::FilesystemAttrs).to receive(:new)
        .and_return(filesystem_attrs_widget)
    end

    it "sets section attributes related to its usage" do
      subject.store

      expect(partition.filesystem).to eq(:ext3)
      expect(partition.label).to eq("mydata")
      expect(partition.mount).to eq("swap")
      expect(partition.mountby).to eq(:label)
      expect(partition.fstab_options).to eq("ro,noatime,user")
      expect(partition.mkfs_options).to eq("-I 128")
    end
  end
end
