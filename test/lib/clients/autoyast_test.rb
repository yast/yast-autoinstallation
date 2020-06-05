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
require "autoinstall/clients/autoyast"

Yast.import "AutoinstConfig"
Yast.import "Y2ModuleConfig"
Yast.import "Profile"

describe Y2Autoinstallation::Clients::Autoyast do
  subject(:client) { described_class.new }

  describe "#main" do
    let(:auto_sequence) do
      instance_double(Y2Autoinstallation::AutoSequence, run: :next)
    end

    before do
      allow(Yast::WFM).to receive(:Args).and_return(args)
      allow(Yast::WFM).to receive(:CallFunction)
      allow(Y2Autoinstallation::AutoSequence).to receive(:new).and_return(auto_sequence)
      # It is changed by other modules which causes this test to fail.
      Yast::Stage.Set("normal")
      Yast::Y2ModuleConfig.main
    end

    describe "'ui' command" do
      let(:path) { File.join(FIXTURES_PATH.join("profiles", "leap.xml")) }
      let(:args) { ["ui", "filename=#{path}"] }

      it "reads and imports the given profile" do
        expect(Yast::WFM).to receive(:CallFunction).with("language_auto", ["Import", Hash])
        client.main
      end

      it "starts the AutoYaST UI" do
        allow(Yast::WFM).to receive(:CallFunction)
        expect(auto_sequence).to receive(:run)
        client.main
      end

      context "when the profile cannot be read" do
        before do
          allow(Yast::Profile).to receive(:ReadXML).and_return(false)
        end

        it "notifies the error" do
          expect(Yast::Popup).to receive(:Error)
          client.main
        end
      end

      context "when a module name is given" do
        let(:args) { ["ui", "modname=kdump"] }

        it "starts the AutoYaST UI with the given module" do
          expect(Yast::AutoinstConfig).to receive(:runModule=).with("kdump")
          expect(auto_sequence).to receive(:run)
          client.main
        end
      end

      context "when was not possible to load the modules configuration" do
        before do
          allow(Yast::Y2ModuleConfig).to receive(:GroupMap).and_return({})
        end

        it "displays an error" do
          expect(Yast::Popup).to receive(:Error)
          client.main
        end
      end
    end

    describe "'list-modules' command" do
      let(:args) { ["list-modules"] }

      it "displays the list of supported modules" do
        expect(Yast::CommandLine).to receive(:PrintTable) do |_header, items|
          expect(items.size).to eq(Yast::Y2ModuleConfig.ModuleMap.size)
          name = Yast::Profile.ModuleMap["lan"]["Name"]
          expect(items.to_s).to include(name)
        end
        client.main
      end
    end
  end
end
