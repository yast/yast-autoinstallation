#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "AutoInstallRules"

describe "Yast::AutoInstallRules" do
  subject { Yast::AutoInstallRules }
  before { Y2Storage::StorageManager.create_test_instance }

  let(:root_path) { File.expand_path('../..', __FILE__) }

  describe "#ProbeRules" do
    before { subject.main }
    let(:devicegraph) { instance_double(Y2Storage::Devicegraph, disk_devices: disk_devices) }
    let(:disk_devices) { [disk] }
    let(:disk) {
      instance_double(Y2Storage::Disk, name: "/dev/sda", size: Y2Storage::DiskSize.MiB(1)) }

    it "detect system properties" do
      allow(Y2Storage::StorageManager.instance).to receive(:probed)
        .and_return(devicegraph)
      allow(Y2Storage::StorageManager.instance.probed).to receive(:disks)
        .and_return([disk])
      allow_any_instance_of(Y2Storage::DiskAnalyzer).to receive(:linux_partitions)
        .and_return([])
      expect_any_instance_of(Y2Storage::DiskAnalyzer).to receive(:windows_partitions)
        .and_return([])
      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".probe.bios")).and_return([])
      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".probe.memory")).and_return([])
      allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
      expect(Yast::Kernel).to receive(:GetPackages).and_return([])
      expect(subject).to receive(:getNetwork).and_return("192.168.1.0")
      expect(subject).to receive(:getHostname).and_return("myhost")
      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".etc.install_inf.XServer"))
      expect(Yast::Hostname).to receive(:CurrentDomain).and_return("mydomain.lan")

      expect(Yast::OSRelease).to receive(:ReleaseInformation).
        and_return("SUSE Linux Enterprise Server 12")
      expect(Yast::OSRelease).to receive(:ReleaseVersion).
        and_return("12")

      subject.ProbeRules

      expect(Yast::AutoInstallRules.installed_product).to eq("SUSE Linux Enterprise Server 12")
      expect(Yast::AutoInstallRules.installed_product_version).to eq("12")
    end
  end

  describe "#getHostid" do
    let(:ip_route_output_path) do
      File.join(root_path, "test", "fixtures", "output", "ip_route.out")
    end

    it "returns host IP in hex format (initial Stage)" do
      expect(Yast::SCR).to receive(:Execute).
        with(Yast::Path.new(".target.bash_output"), /ip route/).
        and_return("stdout" => File.read(ip_route_output_path), "exit" => 0)

      expect(subject.getHostid).to eq(Yast::IP.ToHex("10.13.32.195"))
    end

    it "returns nil if an error occurs finding the IP address" do
      expect(Yast::SCR).to receive(:Execute).
        with(Yast::Path.new(".target.bash_output"), /ip route/).
        and_return("stdout" => "", "stderr" => "error from iputils", "exit" => 1)

      expect(subject.getHostid).to eq(nil)
    end
  end

  describe "#getHostname" do
    before do
      allow(Yast::SCR).to receive(:Execute).
        with(Yast::Path.new(".target.bash_output"), "/bin/hostname").
        and_return(hostname_output)
    end

    context "/bin/hostname returns the hostname properly" do
      let(:hostname_output) { { "stdout" => "myhost", "exit" => 0 } }

      it "returns that hostname" do
        expect(subject.getHostname).to eq("myhost")
      end
    end

    context "/bin/hostname fails" do
      let(:hostname_output) { { "stderr" => "error from hostname", "stdout" => "", "exit" => 1 } }

      before do
        allow(Yast::SCR).to receive(:Read).with(Yast::Path.new(".etc.install_inf.Hostname"))
          .and_return(inf_hostname)
      end

      context "and install.inf contains a Hostname" do
        let(:inf_hostname) { "myhost" }

        it "returns the name stored in install.inf" do
          expect(subject.getHostname).to eq("myhost")
        end
      end

      context "and install.inf does not contain a Hostname" do
        let(:inf_hostname) { nil }

        it "returns nil" do
          expect(subject.getHostname).to eq(nil)
        end
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
       { "hostaddress" => subject.hostaddress, "mac"=> subject.mac}
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
       { "hostaddress" => subject.hostaddress, "mac"=> subject.mac }
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
       { "hostaddress" => subject.hostaddress, "mac"=> subject.mac }
       )
      .and_return({"stdout"=>"", "exit"=>0, "stderr"=>""})

      subject.Read
    end
  end

  describe "#getNetwork" do
    let(:hostaddress) { "10.13.32.195" }
    let(:initial) { true }
    let(:ip_route_output) { { "stdout" => ip_route_content, "exit" => 0 } }
    let(:ip_route_content) do
      File.read(File.join(root_path, "test", "fixtures", "output", "ip_route.out"))
    end

    before do
      allow(subject).to receive(:hostaddress).and_return(hostaddress)
      allow(Yast::SCR).to receive(:Execute).
        with(Yast::Path.new(".target.bash_output"), /ip route/).
        and_return(ip_route_output)
    end

    context "the host address is known to wicked" do
      it "returns the network for the system's hostaddress" do
        expect(subject.getNetwork).to eq("10.13.32.0")
      end
    end

    context "the host address is unknown" do
      let(:hostaddress) { "10.163.2.9" }

      it "returns nil" do
        expect(subject.getNetwork).to be_nil
      end
    end

    context "an error occurs finding the IP" do
      let(:ip_route_output) { { "stderr" => "some error", "stdout" => "", "exit" => 1 } }

      it "returns nil" do
        expect(subject.getNetwork).to be_nil
      end
    end
  end
end
