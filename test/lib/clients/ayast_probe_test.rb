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

require_relative "../../test_helper"
require "autoinstall/clients/ayast_probe"

describe Y2Autoinstall::Clients::AyastProbe do
  subject(:client) { described_class.new }

  before do
    allow(Yast::UI).to receive(:OpenDialog).and_return(true)
    allow(Yast::UI).to receive(:CloseDialog).and_return(true)
  end

  describe "#main" do
    let(:installed_product) { "openSUSE Tumbleweed" }

    before do
      allow(Yast::AutoInstallRules).to receive(:installed_product)
        .and_return(installed_product)
    end

    it "includes autoinstall rules information" do
      expect(client).to receive(:RichText)
        .with(/Keys for rules.*<td>installed_product<\/td><td> = <\/td><td>openSUSE Tumbleweed<br><\/td>/)
      client.main
    end
  end
end
