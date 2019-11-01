#!/usr/bin/env rspec
# Copyright (c) [2017] SUSE LLC
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

require_relative "../../test_helper"
require "autoinstall/dialogs/disk_selector"
require "ostruct"

describe Y2Autoinstallation::Dialogs::DiskSelector do
  subject(:dialog) { described_class.new(devicegraph) }
  extend Yast::I18n

  let(:devicegraph) do
    instance_double(Y2Storage::Devicegraph, disk_devices: disks)
  end

  let(:sda) { double("sda", name: "/dev/sda", basename: "sda", hwinfo: hwinfo) }
  let(:sdb) { double("sdb", name: "/dev/sdb", basename: "sdb", hwinfo: hwinfo) }
  let(:hwinfo) { OpenStruct.new(model: "Model") }
  let(:disks) { [sda, sdb] }

  before do
    allow(Yast::UI).to receive(:OpenDialog).and_return(true)
    allow(Yast::UI).to receive(:CloseDialog).and_return(true)
  end

  describe "#dialog_content" do
    it "displays all options" do
      expect(dialog).to receive(:RadioButton).with(Id("/dev/sda"), "1: sda, Model", true)
      expect(dialog).to receive(:RadioButton).with(Id("/dev/sdb"), "2: sdb, Model", false)
      dialog.dialog_content
    end

    it "displays ok and abort buttons" do
      expect(dialog).to receive(:PushButton).with(Id(:ok), anything, anything)
      expect(dialog).to receive(:PushButton).with(Id(:abort), anything, anything)
      dialog.dialog_content
    end

    context "when a disk must be omitted" do
      subject(:dialog) { described_class.new(devicegraph, blacklist: ["/dev/sda"]) }

      it "does not list the blacklisted disk" do
        expect(dialog).to_not receive(:RadioButton).with(Id("/dev/sda"), anything)
        expect(dialog).to receive(:RadioButton).with(Id("/dev/sdb"), "1: sdb, Model", true)
        dialog.dialog_content
      end
    end

    context "when no disk are found" do
      let(:disks) { [] }

      it "shows an error message" do
        expect(dialog).to receive(:Label).with(_("No disks found."))
        dialog.dialog_content
      end

      it "only shows the abort button" do
        expect(dialog).to_not receive(:PushButton).with(Id(:ok), anything, anything)
        expect(dialog).to receive(:PushButton).with(Id(:abort), anything, anything)
        dialog.dialog_content
      end
    end

    context "when no eligible disks are found" do
      subject(:dialog) { described_class.new(devicegraph, blacklist: ["/dev/sda", "/dev/sdb"]) }

      it "shows an error message" do
        expect(dialog).to receive(:Label).with(_("No disks found."))
        dialog.dialog_content
      end

      it "only shows the abort button" do
        expect(dialog).to_not receive(:PushButton).with(Id(:ok), anything, anything)
        expect(dialog).to receive(:PushButton).with(Id(:abort), anything, anything)
        dialog.dialog_content
      end
    end

    it "contains help text" do
      expect(dialog).to receive(:Label).with(/All hard disks.*the #1 drive/m)
      dialog.dialog_content
    end

    context "when a drive index is specified" do
      subject(:dialog) { described_class.new(devicegraph, drive_index: 2) }

      it "is included in the help text" do
        expect(dialog).to receive(:Label).with(/All hard disks.*the #2 drive/m)
        dialog.dialog_content
      end
    end
  end

  describe "#run" do
    before do
      allow(Yast::UI).to receive(:UserInput).and_return(button)
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:options), :Value)
        .and_return("/dev/sda")
    end

    context "when the user presses 'Continue'" do
      let(:button) { :ok }

      it "returns the selected disk" do
        expect(dialog.run).to eq("/dev/sda")
      end
    end

    context "when the user presses 'Abort'" do
      let(:button) { :abort }

      it "returns :abort" do
        expect(dialog.run).to eq(:abort)
      end
    end
  end
end
