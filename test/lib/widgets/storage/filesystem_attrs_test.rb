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
require "y2storage"
require "autoinstall/widgets/storage/filesystem_attrs"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::FilesystemAttrs do
  subject(:widget) { described_class.new(section) }

  let(:section) do
    Y2Storage::AutoinstProfile::PartitionSection.new
  end

  include_examples "CWM::CustomWidget"

  let(:filesystem_widget) do
    instance_double(
      Y2Autoinstallation::Widgets::Storage::Filesystem,
      widget_id: "filesystem_widget",
      value:     :ext3
    )
  end
  let(:label_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::Label, value: "mydata")
  end
  let(:mount_point_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::Mount, value: "swap")
  end
  let(:mountby_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::Mount, value: :label)
  end
  let(:mkfs_options_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::MkfsOptions, value: "-I 128")
  end
  let(:fstopt_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::Fstopt, value: "ro,noatime,user")
  end
  let(:create_subvolumes_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::CreateSubvolumes, value: false)
  end

  before do
    allow(Y2Autoinstallation::Widgets::Storage::Filesystem).to receive(:new)
      .and_return(filesystem_widget)
    allow(Y2Autoinstallation::Widgets::Storage::Label).to receive(:new)
      .and_return(label_widget)
    allow(Y2Autoinstallation::Widgets::Storage::Mount).to receive(:new)
      .and_return(mount_point_widget)
    allow(Y2Autoinstallation::Widgets::Storage::Mountby).to receive(:new)
      .and_return(mountby_widget)
    allow(Y2Autoinstallation::Widgets::Storage::MkfsOptions).to receive(:new)
      .and_return(mkfs_options_widget)
    allow(Y2Autoinstallation::Widgets::Storage::Fstopt).to receive(:new)
      .and_return(fstopt_widget)
    allow(Y2Autoinstallation::Widgets::Storage::CreateSubvolumes).to receive(:new)
      .and_return(create_subvolumes_widget)
    allow(create_subvolumes_widget).to receive(:enable)
    allow(create_subvolumes_widget).to receive(:disable)
  end

  describe "#init" do
    it "sets initial values" do
      expect(filesystem_widget).to receive(:value=)
      expect(label_widget).to receive(:value=)
      expect(mount_point_widget).to receive(:value=)
      expect(mountby_widget).to receive(:value=)
      expect(mkfs_options_widget).to receive(:value=)
      expect(fstopt_widget).to receive(:value=)
      expect(create_subvolumes_widget).to receive(:value=)

      widget.init
    end
  end

  describe "#handle" do
    let(:event) { { "ID" => filesystem_widget.widget_id } }

    before do
      allow(filesystem_widget).to receive(:value).and_return(filesystem)
    end

    context "when file system is Btrfs" do
      let(:filesystem) { :btrfs }

      it "enables create_subvolumes attribute" do
        expect(create_subvolumes_widget).to receive(:enable)

        widget.handle(event)
      end
    end

    context "when file system is not Btrfs" do
      let(:filesystem) { :ext3 }

      it "disables create_subvolumes attribute" do
        expect(create_subvolumes_widget).to receive(:disable)

        widget.handle(event)
      end
    end
  end

  describe "#values" do
    it "includes label" do
      expect(widget.values).to include("label" => "mydata")
    end

    it "includes mount" do
      expect(widget.values).to include("mount" => "swap")
    end

    it "includes mountby" do
      expect(widget.values).to include("mountby" => :label)
    end

    it "includes mkfs_options" do
      expect(widget.values).to include("mkfs_options" => "-I 128")
    end

    it "includes fstab options" do
      expect(widget.values).to include("fstab_options" => "ro,noatime,user")
    end
  end
end
