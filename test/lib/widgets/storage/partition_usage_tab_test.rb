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

  let(:used_as_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::UsedAs, value: :filesystem)
  end
  let(:filesystem_attrs_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::FilesystemAttrs, values: {})
  end
  let(:encryption_attrs_widget) do
    instance_double(Y2Autoinstallation::Widgets::Storage::EncryptionAttrs, values: {})
  end

  describe "#init" do
    before do
      allow(Y2Autoinstallation::Widgets::Storage::UsedAs).to receive(:new)
        .and_return(used_as_widget)
      allow(used_as_widget).to receive(:value=)
      allow(partition).to receive(:usage).and_return(usage)
    end

    let(:usage) { :raid }

    it "updates the used_as value" do
      expect(used_as_widget).to receive(:value=).with(usage)

      subject.init
    end

    it "updates the UI" do
      expect(subject).to receive(:refresh)

      subject.init
    end
  end

  describe "#handle" do
    context "when handling an 'used_as' event" do
      let(:event) { { "ID" => "used_as" } }

      it "updates the UI" do
        expect(subject).to receive(:refresh)

        subject.handle(event)
      end
    end

    context "when not handling an 'used_as' event" do
      let(:event) { { "ID" => "whatever" } }

      it "does not update the UI" do
        expect(subject).to_not receive(:refresh)

        subject.handle(event)
      end
    end
  end

  describe "#store" do
    before do
      allow(Y2Autoinstallation::Widgets::Storage::FilesystemAttrs).to receive(:new)
        .and_return(filesystem_attrs_widget)
      allow(Y2Autoinstallation::Widgets::Storage::EncryptionAttrs).to receive(:new)
        .and_return(encryption_attrs_widget)
    end

    it "sets the partition section attributes" do
      expect(partition).to receive(:update)
      subject.store
    end
  end
end
