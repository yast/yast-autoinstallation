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
require "autoinstall/widgets/storage/disk_device"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::DiskDevice do
  subject { described_class.new(initial: initial) }
  let(:initial) { "/dev/sdb" }

  include_examples "CWM::ComboBox"

  describe "#init" do
    context "when an initial value is given" do
      it "initializes the value" do
        expect(subject).to receive(:value=).with(initial)
        subject.init
      end
    end

    context "when no initial value was given" do
      subject { described_class.new }

      it "does not initialize the value" do
        expect(subject).to_not receive(:value=)
        subject.init
      end
    end
  end

  describe "#items" do
    let(:initial) { "/dev/test" }

    it "includes the initial value" do
      expect(subject.items).to include([initial, initial])
    end
  end
end
