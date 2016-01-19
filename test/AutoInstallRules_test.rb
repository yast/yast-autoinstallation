#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "AutoInstallRules"

describe Yast::AutoInstallRules do
  subject { Yast::AutoInstallRules }

  let(:root_path) { File.expand_path('../..', __FILE__) }

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

    it "parses Adv. mgmt module CPE ID" do
      machinery_cpeid = "cpe:/o:suse:sle-module-adv-systems-management:12"
      expect(subject.send(:cpeid_map, machinery_cpeid)).to eq(
        "part" => "o",
        "vendor" => "suse",
        "product" => "sle-module-adv-systems-management",
        "version" => "12",
        "update" => nil,
        "edition" => nil,
        "lang" => nil
      )
    end

    it "return nil when CPE ID is does not start with 'cpe:/'" do
      expect(subject.send(:cpeid_map, "invalid")).to be_nil
    end
  end

  describe "#distro_map" do
    it "returns CPEID and product name" do
      param = "cpe:/o:suse:sles:12,SUSE Linux Enterprise Server 12"
      expected = {
        "cpeid" => "cpe:/o:suse:sles:12",
        "name" => "SUSE Linux Enterprise Server 12"
      }

      expect(subject.send(:distro_map, param)).to eq(expected)
    end

    it "returns product name with comma" do
      param = "cpe:/o:suse:sles:12,SLES12, Mini edition"
      expected = {
        "cpeid" => "cpe:/o:suse:sles:12",
        "name" => "SLES12, Mini edition"
      }

      expect(subject.send(:distro_map, param)).to eq(expected)
    end

    it "returns nil if input is nil" do
      expect(subject.send(:distro_map, nil)).to be_nil
    end

    it "returns nil if the input does not contain comma" do
      expect(subject.send(:distro_map, "foo")).to be_nil
    end
  end

  describe "#ProbeRules" do
    it "reads installed product properties from content file" do
      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".probe.bios")).and_return([])
      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".probe.memory")).and_return([])
      expect(Yast::Arch).to receive(:architecture).and_return("x86_64")
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

      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".content.DISTRO")).
        and_return("cpe:/o:suse:sles:12,SUSE Linux Enterprise Server 12")

      subject.ProbeRules

      expect(Yast::AutoInstallRules.installed_product).to eq("SUSE Linux Enterprise Server 12")
      expect(Yast::AutoInstallRules.installed_product_version).to eq("12")
    end

    context "when .content.DISTRO is not found" do
      before(:each) do
        subject.reset
        allow(Yast::SCR).to receive(:Read).with(any_args)
        allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
      end

      it 'set installed_product and installed_product_version to blank string' do
        expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".content.DISTRO")).
          and_return(nil)
        subject.ProbeRules
        expect(Yast::AutoInstallRules.installed_product).to eq('')
        expect(Yast::AutoInstallRules.installed_product_version).to eq('')
      end
    end
  end

  describe "#Rules XML" do
    it "Reading rules with -or- operator" do
      expect(Yast::XML).to receive(:XMLToYCPFile).and_return(
        { "rules"=>[{
            "hostaddress"=>{"match"=>"10.69.57.43",
                            "match_type"=>"exact"},
            "mac"=>{"match"=>"000c2903d288",
                    "match_type"=>"exact"},
            "operator"=>"or",
            "result"=>{"profile"=>"machine12.xml"}}]
         }
      )
      expect(Yast::SCR).to receive(:Execute).with(Yast::Path.new(".target.bash_output"),
       "if  ( [ \"$hostaddress\" = \"10.69.57.43\" ] )   ||   ( [ \"$mac\" = \"000c2903d288\" ] ); then exit 0; else exit 1; fi",
       {"hostaddress"=>"192.168.1.1", "mac"=>""}
       )
      .and_return({"stdout"=>"", "exit"=>0, "stderr"=>""})

      subject.Read
    end

    it "Reading rules with -and- operator" do
      expect(Yast::XML).to receive(:XMLToYCPFile).and_return(
        { "rules"=>[{
            "hostaddress"=>{"match"=>"10.69.57.43",
                            "match_type"=>"exact"},
            "mac"=>{"match"=>"000c2903d288",
                    "match_type"=>"exact"},
            "operator"=>"and",
            "result"=>{"profile"=>"machine12.xml"}}]
         }
      )
      expect(Yast::SCR).to receive(:Execute).with(Yast::Path.new(".target.bash_output"),
       "if  ( [ \"$hostaddress\" = \"10.69.57.43\" ] )   &&   ( [ \"$mac\" = \"000c2903d288\" ] ); then exit 0; else exit 1; fi",
       {"hostaddress"=>"192.168.1.1", "mac"=>""}
       )
      .and_return({"stdout"=>"", "exit"=>0, "stderr"=>""})

      subject.Read
    end

    it "Reading rules with default operator" do
      expect(Yast::XML).to receive(:XMLToYCPFile).and_return(
        { "rules"=>[{
            "hostaddress"=>{"match"=>"10.69.57.43",
                            "match_type"=>"exact"},
            "mac"=>{"match"=>"000c2903d288",
                    "match_type"=>"exact"},
            "result"=>{"profile"=>"machine12.xml"}}]
         }
      )
      expect(Yast::SCR).to receive(:Execute).with(Yast::Path.new(".target.bash_output"),
       "if  ( [ \"$hostaddress\" = \"10.69.57.43\" ] )   &&   ( [ \"$mac\" = \"000c2903d288\" ] ); then exit 0; else exit 1; fi",
       {"hostaddress"=>"192.168.1.1", "mac"=>""}
       )
      .and_return({"stdout"=>"", "exit"=>0, "stderr"=>""})

      subject.Read
    end
  end

  describe "#Host ID" do
    let(:wicked_output_path) { File.join(root_path, 'test', 'fixtures', 'output', 'wicked_output')  }
    it "returns host IP in hex format (initial Stage)" do
      expect(Yast::SCR).to receive(:Execute).with(Yast::Path.new(".target.bash_output"), "/usr/sbin/wicked show --verbose all|grep pref-src").and_return({"stdout"=>File.read(wicked_output_path), "exit"=>0})
      expect(Yast::Stage).to receive(:initial).and_return(true)
      expect(subject.getHostid).to eq("C0A864DA")
    end

    it "returns fix 192.168.1.1 in hex format (normal Stage)" do
      expect(Yast::Stage).to receive(:initial).and_return(false)
      expect(subject.getHostid).to eq("C0A80101")
    end

    it "returns nil if wicked does not find IP address" do
      expect(Yast::Stage).to receive(:initial).and_return(true)
      expect(Yast::SCR).to receive(:Execute).with(Yast::Path.new(".target.bash_output"), "/usr/sbin/wicked show --verbose all|grep pref-src").and_return({"stderr"=>"error from wicked", "exit"=>1})
      expect(subject.getHostid).to eq(nil)
    end

  end


end
