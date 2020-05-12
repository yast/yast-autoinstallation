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
require "autoinstall/presenters"
require "y2storage/autoinst_profile"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::CommonPartitionAttrs do
  include_examples "CWM::CustomWidget"

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(part_hashes)
  end

  let(:part_hashes) do
    [{ "type" => :CT_DISK }]
  end

  let(:section) { Y2Storage::AutoinstProfile::PartitionSection.new }

  let(:drive_section) do
    sect = partitioning.drives.first
    sect.partitions << section
    sect
  end

  let(:drive) { Y2Autoinstallation::Presenters::Drive.new(drive_section) }

  subject { described_class.new(drive.partitions.first) }

  let(:section) do
    Y2Storage::AutoinstProfile::PartitionSection.new
  end

  describe "#contents" do
    it "constains a widget to set the create option" do
      widget = subject.contents.nested_find do |w|
        w.is_a?(Y2Autoinstallation::Widgets::Storage::Create)
      end

      expect(widget).to_not be_nil
    end

    it "constains a widget to fill the size" do
      widget = subject.contents.nested_find do |w|
        w.is_a?(Y2Autoinstallation::Widgets::Storage::SizeSelector)
      end

      expect(widget).to_not be_nil
    end
  end

  describe "#values" do
    let(:create_widget) do
      instance_double(Y2Autoinstallation::Widgets::Storage::Create, value: "false")
    end

    before do
      allow(Y2Autoinstallation::Widgets::Storage::Create).to receive(:new)
        .and_return(create_widget)
    end

    it "includes create" do
      expect(subject.values).to include("create" => "false")
    end
  end
end
