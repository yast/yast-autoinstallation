#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "AutoInstallRules"

describe "Yast::AutoInstallRules" do
  subject { Yast::AutoInstallRules }

  describe "#cpeid_map" do
    it "parses SLES12 CPE ID" do
      expect(subject.send(:cpeid_map, "cpe:/o:suse:sles:12")).to eq(
        "part" => "o",
        "vendor" => "suse",
        "product" => "sles",
        "version" => "12",
        "update" => nil,
        "edition" => nil,
        "lang" => nil
      )
    end
  end

  describe "#distro_map" do
    it "returns CPEID and product name" do
      expect(subject.send(:distro_map, "cpe:/o:suse:sles:12,SUSE Linux Enterprise Server 12")).
        to eq({"cpeid" => "cpe:/o:suse:sles:12",
          "name" => "SUSE Linux Enterprise Server 12"})
    end

    it "returns product name with comma" do
      expect(subject.send(:distro_map, "cpe:/o:suse:sles:12,SLES12, Mini edition")).
        to eq({"cpeid" => "cpe:/o:suse:sles:12",
          "name" => "SLES12, Mini edition"})
    end

    it "returns nil if input is nil" do
      expect(subject.send(:distro_map, nil)).to be_nil
    end

    it "returns nil if input is invalid" do
      expect(subject.send(:distro_map, "foo")).to be_nil
    end
  end

  describe "#ProbeRules" do
    it "reads installed product properties from content file" do
      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".probe.bios")).and_return([])
      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".probe.memory")).and_return([])
      expect(Yast::Kernel).to receive(:GetPackages).and_return([])
      expect(Yast::SCR).to receive(:Execute).with(Yast::Path.new(".target.bash_output"), "/bin/hostname")
      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".etc.install_inf.Domain"))
      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".etc.install_inf.Hostname"))
      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".etc.install_inf.Network"))
      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".etc.install_inf.HasPCMCIA"))
      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".etc.install_inf.XServer"))

      expect(Yast::StorageControllers).to receive(:Initialize)
      expect(Yast::Storage).to receive(:GetTargetMap).and_return({})
      expect(Yast::Storage).to receive(:GetForeignPrimary)
      expect(Yast::Storage).to receive(:GetOtherLinuxPartitions)

      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".content.distro")).
        and_return("cpe:/o:suse:sles:12,SUSE Linux Enterprise Server 12")

      subject.ProbeRules

      expect(Yast::AutoInstallRules.installed_product).to eq("SUSE Linux Enterprise Server 12")
      expect(Yast::AutoInstallRules.installed_product_version).to eq("12")
    end
  end

end
