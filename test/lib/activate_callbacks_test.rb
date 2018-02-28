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
require "autoinstall/activate_callbacks"

describe Y2Autoinstallation::ActivateCallbacks do
  subject(:callbacks) { described_class.new }

  describe "#multipath" do
    let(:general_settings) { { "start_multipath" => start_multipath } }

    before do
      allow(Yast::AutoinstStorage).to receive(:general_settings)
        .and_return(general_settings)
    end

    context "if start_multipath is set to 'true'" do
      let(:start_multipath) { true }

      it "returns true" do
        expect(callbacks.multipath(true)).to eq(true)
      end
    end

    context "if start_multipath is set to 'false'" do
      let(:start_multipath) { false }

      it "returns false" do
        expect(callbacks.multipath(true)).to eq(false)
      end
    end

    context "if start_multipath is not set" do
      let(:start_multipath) { false }

      it "returns false" do
        expect(callbacks.multipath(true)).to eq(false)
      end
    end
  end

  describe "#luks" do
    it "returns (false, '') pair" do
      ret = callbacks.luks('uuid', 1)
      expect(ret.first).to eq(false)
      expect(ret.second).to eq("")
    end
  end
end
