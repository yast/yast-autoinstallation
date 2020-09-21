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
        "X-SuSE-YaST-Group"            => "Software",
        "X-SuSE-YaST-AutoInstClonable" => "true",
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
        "X-SuSE-YaST-Group"            => "System",
        "X-SuSE-DocTeamID"             => "ycc_org.opensuse.yast.Bootloader",
        "X-SuSE-YaST-AutoInstClient"   => "bootloader_auto"
      }
    }
  end

  let(:probed_devicegraph) do
    instance_double(Y2Storage::Devicegraph, multipaths: multipaths)
  end

  let(:multipaths) { [] }

  before do
    Y2Storage::StorageManager.create_test_instance
    allow(Yast::Y2ModuleConfig).to receive(:ModuleMap).and_return(module_map)
    allow(Y2Storage::StorageManager.instance).to receive(:probed).and_return(probed_devicegraph)
    subject.additional = ["add-on"]
    Yast::Mode.SetMode("normal")
  end

  describe "#Process" do
    before do
      allow(subject).to receive(:CommonClone)
      allow(Yast::Profile).to receive(:Prepare)
    end

    it "sets Mode to 'autoinst_config'" do
      expect { subject.Process }.to change { Yast::Mode.mode }.from("normal").to("autoinst_config")
    end

    it "clones 'additional' modules" do
      expect(subject).to receive(:CommonClone).with("add-on", module_map["add-on"])
      subject.Process
    end

    it "imports 'general' and 'report' settings" do
      expect(Yast::Call).to receive(:Function).with("general_auto", ["Import", Hash])
      expect(Yast::Call).to receive(:Function).with("general_auto", ["SetModified"])
      expect(Yast::Call).to receive(:Function).with("report_auto", ["Import", Hash])
      expect(Yast::Call).to receive(:Function).with("report_auto", ["SetModified"])
      subject.Process
    end

    it "asks the profile to 'prepare'" do
      expect(Yast::Profile).to receive(:Reset)
      expect(Yast::Profile).to receive(:prepare=).with(true)
      expect(Yast::Profile).to receive(:Prepare)
      subject.Process
    end
  end

  describe "#CommonClone" do
    let(:resource_map) { module_map["add-on"] }
    let(:initial_stage) { false }

    before do
      allow(Yast::Call).to receive(:Function)
      allow(Yast::Stage).to receive(:initial).and_return(initial_stage)
    end

    it "returns true" do
      expect(subject.CommonClone("dummy", resource_map)).to eq(true)
    end

    it "reads the module settings" do
      expect(Yast::Call).to receive(:Function).with("add-on_auto", ["Read"])
      subject.CommonClone("dummy", resource_map)
    end

    it "sets the module as modified" do
      expect(Yast::Call).to receive(:Function).with("add-on_auto", ["SetModified"])
      subject.CommonClone("dummy", resource_map)
    end

    context "on 1st stage" do
      let(:initial_stage) { true }

      it "does not read the module settings" do
        expect(Yast::Call).to_not receive(:Function).with(anything, ["Read"])
        subject.CommonClone("dummy", resource_map)
      end

      it "sets the module as modified" do
        expect(Yast::Call).to receive(:Function).with("add-on_auto", ["SetModified"])
        subject.CommonClone("dummy", resource_map)
      end

      context "when cloning the software module" do
        let(:resource_map) do
          { "X-SuSE-YaST-AutoInstClient" => "software_auto" }
        end

        it "reads the module settings" do
          expect(Yast::Call).to receive(:Function).with("software_auto", ["Read"])
          subject.CommonClone("dummy", resource_map)
        end
      end

      context "when cloning the storage module" do
        let(:resource_map) do
          { "X-SuSE-YaST-AutoInstClient" => "storage_auto" }
        end

        it "reads the module settings" do
          expect(Yast::Call).to receive(:Function).with("storage_auto", ["Read"])
          subject.CommonClone("dummy", resource_map)
        end
      end
    end
  end

  describe "#General" do
    it "includes installation mode configuration" do
      expect(subject.General).to include("mode" => { "confirm" => false })
    end

    it "includes signature handling settings" do
      expect(subject.General).to_not include("signature-handling" => Hash)
    end

    context "when multipath is not enabled" do
      it "does not include the 'start_multipath' setting" do
        expect(subject.General).to_not have_key("storage")
      end
    end

    context "when multipath is enabled" do
      let(:multipaths) { [double("multipath")] }

      it "includes the 'start_multipath' setting" do
        expect(subject.General).to include("storage" => { "start_multipath" => true })
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
        .to receive(:dpgettext)
          .with("desktop_translations", "/usr/share/locale/", /Bootloader/) { |*a| a.last }
    end

    it "returns a list of modules to clone with translated names" do
      modules = subject.createClonableList
      items = modules.map(&:params)
      names = items.map(&:last)
      expect(names).to eq(["Add-On (translated)", "YaST Boot Loader"])
    end
  end
end
