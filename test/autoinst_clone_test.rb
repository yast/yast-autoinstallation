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

require_relative "test_helper"

Yast.import "AutoinstClone"

describe Yast::AutoinstClone do
  subject { Yast::AutoinstClone }

  let(:module_map) do
    {

      "add-on"     => {
        "Name"                         => "YaST Add-On Products",
        "Icon"                         => "yast-addon",
        "X-SuSE-YaST-AutoInst"         => "configure",
        "X-SuSE-YaST-AutoInstResource" => "add-on",
        "X-SuSE-YaST-AutoInstClonable" => "true",
        "X-SuSE-YaST-Group"            => "Software",
        "X-SuSE-DocTeamID"             => "ycc_org.opensuse.yast.AddOn",
        "X-SuSE-YaST-AutoInstClient"   => "add-on_auto"
      },
      "general"    => {
        "Name"                         => "General Options",
        "Icon"                         => "yast-general",
        "X-SuSE-YaST-AutoInst"         => "configure",
        "X-SuSE-YaST-AutoInstResource" => "general",
        "X-SuSE-YaST-Group"            => "System",
        "X-SuSE-YaST-AutoInstClient"   => "general_auto"
      },
      "report"     => {
        "Name"                         => "Report & Logging",
        "Icon"                         => "yast-report",
        "X-SuSE-YaST-AutoInst"         => "configure",
        "X-SuSE-YaST-AutoInstResource" => "report",
        "X-SuSE-YaST-Group"            => "System",
        "X-SuSE-YaST-AutoInstClient"   => "report_auto"
      },
      "bootloader" => {
        "Name"                         => "YaST Boot Loader",
        "Icon"                         => "yast-bootloader",
        "X-SuSE-YaST-AutoInst"         => "configure",
        "X-SuSE-YaST-AutoInstResource" => "bootloader",
        "X-SuSE-YaST-AutoInstClonable" => "true",
        "X-SuSE-YaST-Group"            => "System",
        "X-SuSE-DocTeamID"             => "ycc_org.opensuse.yast.Bootloader",
        "X-SuSE-YaST-AutoInstClient"   => "bootloader_auto"
      },
      "software"   => {
        "Name"                         => "Software",
        "Icon"                         => "yast-sw_single",
        "X-SuSE-YaST-AutoInst"         => "configure",
        "X-SuSE-YaST-AutoInstResource" => "software",
        "X-SuSE-YaST-AutoInstClonable" => "true",
        "X-SuSE-YaST-Group"            => "System",
        "X-SuSE-DocTeamID"             => "ycc_org.opensuse.yast.Software",
        "X-SuSE-YaST-AutoInstClient"   => "software_auto"
      },
      "storage"    => {
        "Name"                         => "Storage",
        "Icon"                         => "yast-storage",
        "X-SuSE-YaST-AutoInst"         => "configure",
        "X-SuSE-YaST-AutoInstResource" => "storage",
        "X-SuSE-YaST-AutoInstClonable" => "true",
        "X-SuSE-YaST-Group"            => "System",
        "X-SuSE-DocTeamID"             => "ycc_org.opensuse.yast.Storage",
        "X-SuSE-YaST-AutoInstClient"   => "storage_auto"
      }
    }
  end

  let(:storage_scenario) { "autoyast_drive_examples.yml" }

  before do
    allow(Yast::Y2ModuleConfig).to receive(:ModuleMap).and_return(module_map)
    fake_storage_scenario(storage_scenario)
    subject.additional = ["add-on"]
  end

  around do |example|
    orig_mode = Yast::Mode.mode
    Yast::Mode.SetMode("normal")
    example.call
    Yast::Mode.SetMode(orig_mode)
  end

  describe "#Process" do
    let(:resource_map) { module_map["add-on"] }
    let(:initial_stage) { false }

    before do
      allow(Yast::Profile).to receive(:create)
      allow(Yast::Call).to receive(:Function)
      allow(Yast::Stage).to receive(:initial).and_return(initial_stage)
      subject.additional = ["add-on"]
    end

    it "sets Mode to 'autoinst_config'" do
      expect { subject.Process }.to change { Yast::Mode.mode }.from("normal").to("autoinst_config")
    end

    it "reads the module settings" do
      expect(Yast::Call).to receive(:Function).with("add-on_auto", ["Read"])
      subject.Process
    end

    it "imports 'general' settings when general is in additional modules" do
      subject.additional = ["general"]
      expect(Yast::Call).to receive(:Function).with("general_auto", ["Import", Hash])
      subject.Process
    end

    it "creates profile with additional modules" do
      subject.additional = ["general"]
      expect(Yast::Profile).to receive(:create).with(["general"], target: :default)
      subject.Process
    end

    context "on 1st stage" do
      let(:initial_stage) { true }

      it "does not read the module settings" do
        expect(Yast::Call).to_not receive(:Function).with(anything, ["Read"])
        subject.Process
      end

      context "when cloning the software module" do
        it "reads the module settings" do
          subject.additional = ["software"]
          expect(Yast::Call).to receive(:Function).with("software_auto", ["Read"])
          subject.Process
        end
      end

      context "when cloning the storage module" do
        it "reads the module settings" do
          subject.additional = ["storage"]
          expect(Yast::Call).to receive(:Function).with("storage_auto", ["Read"])
          subject.Process
        end
      end
    end

    context "when a target is given" do
      it "applies the target when creating the file" do
        expect(Yast::Profile).to receive(:create).with(Array, target: :compact)
        subject.Process(target: :compact)
      end
    end
  end

  describe "#General" do
    it "includes installation mode configuration" do
      expect(subject.send(:General)).to include("mode" => { "confirm" => false })
    end

    it "includes signature handling settings" do
      expect(subject.send(:General)).to_not include("signature-handling" => Hash)
    end

    context "when multipath is not enabled" do
      it "does not include the 'start_multipath' setting" do
        expect(subject.send(:General)).to_not have_key("storage")
      end
    end

    context "when multipath is enabled" do
      let(:storage_scenario) { "multipath.xml" }

      it "includes the 'start_multipath' setting" do
        expect(subject.send(:General)).to include("storage" => { "start_multipath" => true })
      end
    end
  end

  describe "#createClonableList" do
    before do
      allow(Yast::Builtins)
        .to receive(:dpgettext)
        .with(
          "desktop_translations",
          "/usr/share/locale/",
          "Name(org.opensuse.yast.AddOn.desktop): YaST Add-On Products"
        ).and_return("Add-On (translated)")

      allow(Yast::Builtins)
        .to receive(:dpgettext) { |*a| a.last }
    end

    it "returns a list of modules to clone with translated names" do
      modules = subject.createClonableList
      items = modules.map(&:params)
      names = items.map(&:last)
      expect(names).to match_array(
        ["Software", "Storage", "YaST Add-On Products", "YaST Boot Loader"]
      )
    end
  end
end
