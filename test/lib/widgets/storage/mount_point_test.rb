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
require "autoinstall/widgets/storage/mount_point"
require "cwm/rspec"

describe Y2Autoinstallation::Widgets::Storage::MountPoint do
  subject { described_class.new }

  include_examples "CWM::ComboBox"

  describe "#value=" do
    let(:unknown) { "/opt" }

    context "when an unknown value is given" do
      it "adds the value to the list of items" do
        subject.value = unknown
        expect(subject.items.map(&:first)).to include(unknown)
      end

      it "sets the current value" do
        allow(Yast::UI).to receive(:ChangeWidget)
          .with(anything, :Items, anything)
        expect(Yast::UI).to receive(:ChangeWidget)
          .with(anything, :Value, unknown)
        subject.value = unknown
      end
    end
  end
end
