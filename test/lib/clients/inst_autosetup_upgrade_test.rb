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
require "autoinstall/clients/inst_autosetup_upgrade"

# TODO: just temporary workaround for missing require
require "y2packager/resolvable"

describe Y2Autoinstallation::Clients::InstAutosetupUpgrade do
  let(:profile) do
    {
      "general" => {}
    }
  end

  before do
    allow(subject).to receive(:probe_storage)
    allow(Yast::Packages).to receive(:Init)
    allow(Yast::Pkg).to receive(:Resolvables).and_return([])
    allow(Yast::Profile).to receive(:current).and_return(profile)
    # mock other clients call
    allow(Yast::WFM).to receive(:CallFunction).and_return(:next)
  end

  describe "#main" do
    it "shows a progress" do
      expect(Yast::Progress).to receive(:New).at_least(:once)

      subject.main
    end
  end
end

