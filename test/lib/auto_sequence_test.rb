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

require_relative "../test_helper"
require "autoinstall/auto_sequence"
require "autoinstall/entries/registry"

describe Y2Autoinstallation::AutoSequence do
  let(:sequence) { described_class.new }

  let(:module_map) do
    path = File.expand_path("../fixtures/desktop_files/desktops.yml", __dir__)
    YAML.safe_load(File.read(path))
  end

  let(:groups) do
    path = File.expand_path("../fixtures/desktop_files/groups.yml", __dir__)
    YAML.safe_load(File.read(path))
  end

  before do
    # reset singleton
    allow(Yast::Desktop).to receive(:Modules)
      .and_return(module_map)
    allow(Yast::Desktop).to receive(:Groups)
      .and_return(module_map)
    Singleton.__init__(Y2Autoinstallation::Entries::Registry)
  end

  describe "#run" do
    it "opens the main dialog" do
      expect(sequence).to receive(:MainDialog).and_return(:exit)
      sequence.run
    end
  end
end
