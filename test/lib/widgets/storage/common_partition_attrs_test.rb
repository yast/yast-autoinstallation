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
require "autoinstall/widgets/storage/common_partition_attrs"
require "y2storage/autoinst_profile"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::CommonPartitionAttrs do
  subject { described_class.new(section) }

  include_examples "CWM::CustomWidget"

  let(:section) { Y2Storage::AutoinstProfile::PartitionSection.new }

  describe "#contents" do
    it "constains a widget to set the create option" do
      widget = subject.contents.nested_find do |w|
        w.is_a?(Y2Autoinstallation::Widgets::Storage::Create)
      end

      expect(widget).to_not be_nil
    end

    it "constains a widget to set the format option" do
      widget = subject.contents.nested_find do |w|
        w.is_a?(Y2Autoinstallation::Widgets::Storage::Format)
      end

      expect(widget).to_not be_nil
    end

    it "constains a widget to fill the size" do
      widget = subject.contents.nested_find do |w|
        w.is_a?(Y2Autoinstallation::Widgets::Storage::SizeSelector)
      end

      expect(widget).to_not be_nil
    end

    it "constains a widget to set the partition number" do
      widget = subject.contents.nested_find do |w|
        w.is_a?(Y2Autoinstallation::Widgets::Storage::PartitionNr)
      end

      expect(widget).to_not be_nil
    end

    it "constains a widget to set the partition uuid" do
      widget = subject.contents.nested_find do |w|
        w.is_a?(Y2Autoinstallation::Widgets::Storage::Uuid)
      end

      expect(widget).to_not be_nil
    end
  end

  shared_context "mock widgets" do
    let(:create_widget) do
      instance_double(Y2Autoinstallation::Widgets::Storage::Create, value: "false")
    end
    let(:format_widget) do
      instance_double(Y2Autoinstallation::Widgets::Storage::Format, value: "true")
    end
    let(:resize_widget) do
      instance_double(Y2Autoinstallation::Widgets::Storage::Resize, value: "true")
    end
    let(:size_widget) do
      instance_double(Y2Autoinstallation::Widgets::Storage::Size, value: "1TB")
    end
    let(:partition_nr_widget) do
      instance_double(Y2Autoinstallation::Widgets::Storage::PartitionNr, value: 131)
    end
    let(:uuid_widget) do
      instance_double(Y2Autoinstallation::Widgets::Storage::Uuid, value: "partition-uuid")
    end

    before do
      allow(Y2Autoinstallation::Widgets::Storage::Create).to receive(:new)
        .and_return(create_widget)
      allow(Y2Autoinstallation::Widgets::Storage::Format).to receive(:new)
        .and_return(format_widget)
      allow(Y2Autoinstallation::Widgets::Storage::Resize).to receive(:new)
        .and_return(resize_widget)
      allow(Y2Autoinstallation::Widgets::Storage::Size).to receive(:new)
        .and_return(size_widget)
      allow(Y2Autoinstallation::Widgets::Storage::PartitionNr).to receive(:new)
        .and_return(partition_nr_widget)
      allow(Y2Autoinstallation::Widgets::Storage::Uuid).to receive(:new)
        .and_return(uuid_widget)
    end
  end

  describe "#init" do
    include_context "mock widgets"

    it "sets initial values" do
      expect(create_widget).to receive(:value=)
      expect(format_widget).to receive(:value=)
      expect(resize_widget).to receive(:value=)
      expect(size_widget).to receive(:value=)
      expect(partition_nr_widget).to receive(:value=)
      expect(uuid_widget).to receive(:value=)

      subject.init
    end
  end

  describe "#values" do
    include_context "mock widgets"

    it "includes create" do
      expect(subject.values).to include("create" => "false")
    end

    it "includes format" do
      expect(subject.values).to include("format" => "true")
    end

    it "includes resize" do
      expect(subject.values).to include("resize" => "true")
    end

    it "includes size" do
      expect(subject.values).to include("size" => "1TB")
    end

    it "includes partition_nr" do
      expect(subject.values).to include("partition_nr" => 131)
    end

    it "includes uuid" do
      expect(subject.values).to include("uuid" => "partition-uuid")
    end
  end
end
