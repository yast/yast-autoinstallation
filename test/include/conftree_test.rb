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

require "yast"
Yast.import "Y2ModuleConfig"

describe "Yast::AutoinstallConfTreeInclude" do
  class DummyClient < Yast::Client
    include Yast::I18n

    def main
      Yast.include self, "autoinstall/conftree.rb"
    end
  end

  let(:subject) { DummyClient.new.tap(&:main) }

  describe "#configureModule" do
    let(:module_map) do
      {
        "report" => {
          "Name"                         => "Report & Logging",
          "Icon"                         => "yast-report",
          "X-SuSE-YaST-AutoInst"         => "configure",
          "X-SuSE-YaST-AutoInstResource" => "report",
          "X-SuSE-YaST-Group"            => "System",
          "X-SuSE-YaST-AutoInstClient"   => "report_auto"
        }
      }
    end

    let(:resource) { "report" }

    let(:original_settings) do
      { "messages" => { "show" => false } }
    end

    let(:changed_settings) do
      { "messages" => { "show" => true, "timeout" => 30 } }
    end

    before do
      allow(Yast::Y2ModuleConfig).to receive(:ModuleMap).and_return(module_map)
      allow(Yast::WFM).to receive(:CallFunction).once.with("report_auto", ["Export"])
        .and_return(original_settings, changed_settings)

      allow(Yast::WFM).to receive(:CallFunction).with("report_auto", ["Change"])
        .and_return(change_result)
      allow(Yast::WFM).to receive(:CallFunction).with("report_auto", ["SetModified"])
    end

    context "when the user accepts the configuration dialog" do
      let(:change_result) { :accept }

      context "and the settings have been changed" do
        it "sets the module and the profile as modified" do
          expect(Yast::WFM).to receive(:CallFunction).with("report_auto", ["SetModified"])
          expect(Yast::Profile).to receive(:changed=).with(true)
          expect(Yast::Profile).to receive(:prepare=).with(true)
          subject.configureModule(resource)
        end
      end

      context "and the settings has not been changed" do
        let(:changed_settings) { original_settings }

        it "does not set the module or profile as modified" do
          expect(Yast::WFM).to_not receive(:CallFunction).with("report_auto", ["SetModified"])
          expect(Yast::Profile).to_not receive(:changed=)
          expect(Yast::Profile).to_not receive(:prepare=)
          subject.configureModule(resource)
        end
      end

      context "when new settings are not valid" do
        let(:changed_settings) { nil }

        before do
          allow(Yast::Popup).to receive(:Error)
          allow(Yast::WFM).to receive(:CallFunction)
            .with("report_auto", ["Import", original_settings])
        end

        it "imports the original settings again" do
          expect(Yast::WFM).to receive(:CallFunction)
            .with("report_auto", ["Import", original_settings])
          subject.configureModule(resource)
        end

        it "reports the error and returns :abort" do
          expect(Yast::Popup).to receive(:Error)
          expect(subject.configureModule(resource)).to eq(:abort)
        end
      end
    end

    context "when the user aborts the configuration dialog" do
      let(:change_result) { :cancel }

      it "imports the original settings again" do
        expect(Yast::WFM).to receive(:CallFunction)
          .with("report_auto", ["Import", original_settings])
        subject.configureModule(resource)
      end
    end
  end
end
