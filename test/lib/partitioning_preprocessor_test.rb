#!/usr/bin/env rspec
# encoding: utf-8

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

require_relative "../test_helper"
require "autoinstall/partitioning_preprocessor"

describe Y2Autoinstallation::PartitioningPreprocessor do
  subject(:preprocessor) { described_class.new }

  let(:profile) do
    [sda, undefined]
  end

  let(:sda) { { "device" => "/dev/sda" } }
  let(:selected) { "/dev/sdb" }
  let(:undefined) { { "device" => "ask" } }

  let(:disk_selector) do
    instance_double(Y2Autoinstallation::Dialogs::DiskSelector, run: selected)
  end

  before do
    allow(Y2Autoinstallation::Dialogs::DiskSelector).to receive(:new).and_return(disk_selector)
  end

  describe "#run" do
    it "sets disk devices when device=ask" do
      expect(preprocessor.run(profile)).to eq([sda, { "device" => selected }])
    end

    it "asks the user about which device to use" do
      expect(disk_selector).to receive(:run).and_return(selected)
      preprocessor.run(profile)
    end

    context "when the user aborts" do
      let(:selected) { :abort }

      it "returns nil" do
        expect(preprocessor.run(profile)).to be_nil
      end
    end
  end
end
