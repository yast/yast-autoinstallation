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
require "autoinstall/profile_checker"

describe Y2Autoinstallation::ProfileChecker do
  let(:import_all) { false }
  let(:run_scripts) { false }
  let(:target_file) { "~/test.xml" }

  subject do
    described_class.new(fixture_xml("leap.xml"), import_all: import_all,
    run_scripts: run_scripts, target_file: target_file)
  end

  def fixture_xml(filename)
    File.expand_path("#{__dir__}/../fixtures/profiles/#{filename}")
  end

  before do
    allow(::FileUtils).to receive(:cp) # no messing of fs
    allow(Yast2::Popup).to receive(:show) # no popups
    allow(Yast::ProfileLocation).to receive(:Process).and_return(true)
  end

  describe "#check" do
    it "sets mode to dialog mode to show UI" do
      expect(Yast::Mode).to receive(:SetUI).with("dialog")

      subject.check
    end

    it "fetches profile same as real autoinstallation" do
      expect(Yast::AutoinstConfig).to receive(:ParseCmdLine)
      expect(Yast::ProfileLocation).to receive(:Process).and_return(true)

      subject.check
    end

    context "import_all flag is set" do
      let(:import_all) { true }

      before do
        allow(Yast::Profile).to receive(:ReadXML)
        allow(Y2Autoinstallation::Importer).to receive(:new)
          .and_return(double(import_sections: true))
        allow(Yast::AutoInstall).to receive(:valid_imported_values)
      end

      it "imports all sections in profile" do
        expect(Yast::Profile).to receive(:ReadXML)
        expect(Y2Autoinstallation::Importer).to receive(:new)
          .and_return(double(import_sections: true))

        subject.check
      end

      it "check if there are any autoinst issue" do
        expect(Yast::AutoInstall).to receive(:valid_imported_values)

        subject.check
      end
    end

    context "run_scripts flag is set" do
      let(:run_scripts) { true }

      before do
        allow(Yast::Profile).to receive(:ReadXML)
        allow(Yast::AutoinstScripts).to receive(:Write)
        allow(::FileUtils).to receive(:rm_r)
        allow(::FileUtils).to receive(:mkdir_p)
        allow(::FileUtils).to receive(:cp)
        allow(Yast::Mode).to receive(:SetMode)
      end

      it "sets autoinstallation mode" do
        expect(Yast::Mode).to receive(:SetMode).with("autoinstallation")

        subject.check
      end

      it "ensures that scripts are imported even when import_all is not set" do
        expect(Yast::AutoinstScripts).to receive(:Import)

        subject.check
      end

      it "runs all defined scripts" do
        expect(Yast::AutoinstScripts).to receive(:Write)

        subject.check
      end
    end
  end
end
