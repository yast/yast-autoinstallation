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

require_relative "../../test_helper"
require "autoinstall/clients/scripts_auto"

describe Y2Autoinstallation::Clients::ScriptsAuto do
  let(:mod) { Yast::AutoinstScripts }
  describe "#import" do
    it "imports its param" do
      expect(mod).to receive(:Import).with({})

      subject.import({})
    end
  end

  describe "#summary" do
    it "returns scripts summary" do
      expect(mod).to receive(:Summary)

      subject.summary
    end
  end

  describe "#reset" do
    it "repropose module" do
      expect(mod).to receive(:Import).with({})

      subject.reset
    end
  end

  describe "#modified?" do
    it "returns modified flag" do
      expect(mod).to receive(:GetModified).and_return(true)

      expect(subject.modified?).to eq true
    end
  end

  describe "#modified" do
    it "sets modified flag" do
      expect(mod).to receive(:SetModified)

      subject.modified
    end
  end

  describe "#export" do
    it "exports configuration" do
      expect(mod).to receive(:Export).and_return({})

      expect(subject.export).to eq({})
    end
  end

  describe "#change" do
    # note: It do more testing also of script_dialogs include as it is only user

    before do
      allow(Yast::UI).to receive(:UserInput).and_return(:next)
    end

    it "opens wizard" do
      expect(Yast::Wizard).to receive(:CreateDialog)

      subject.change
    end

    it "sets icon" do
      expect(Yast::Wizard).to receive(:SetDesktopIcon)

      subject.change
    end

    it "closes wizard window after wards" do
      expect(Yast::Wizard).to receive(:CloseDialog)

      subject.change
    end

    it "runs scripts dialog" do
      # test run with creating new script and finishing
      expect(Yast::UI).to receive(:UserInput).and_return(:new, :save, :next)
      expect(Yast::AutoinstScripts).to receive(:AddEditScript)

      expect(subject.change).to eq :next
    end
  end
end
