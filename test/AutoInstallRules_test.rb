#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "AutoInstallRules"

describe "Yast::AutoInstallRules" do
  subject { Yast::AutoInstallRules }

  let(:root_path) { File.expand_path('../..', __FILE__) }

  describe "#ProbeRules" do
    it "detect system properties" do
      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".probe.bios")).and_return([])
      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".probe.memory")).and_return([])
      expect(Yast::Arch).to receive(:architecture).and_return("x86_64")
      expect(Yast::Kernel).to receive(:GetPackages).and_return([])
      expect(subject).to receive(:getNetwork).and_return("192.168.1.0")
      expect(subject).to receive(:getHostname).and_return("myhost")
      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".etc.install_inf.HasPCMCIA"))
      expect(Yast::SCR).to receive(:Read).with(Yast::Path.new(".etc.install_inf.XServer"))
      expect(Yast::Hostname).to receive(:CurrentDomain).and_return("mydomain.lan")

      expect(Yast::StorageControllers).to receive(:Initialize)
      expect(Yast::Storage).to receive(:GetTargetMap).and_return({})
      expect(Yast::Storage).to receive(:GetForeignPrimary)
      expect(Yast::Storage).to receive(:GetOtherLinuxPartitions)

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
    let(:wicked_output_path) do
      File.join(root_path, "test", "fixtures", "network", "wicked_partial.out")
    end

    it "returns host IP in hex format (initial Stage)" do
      expect(Yast::SCR).to receive(:Execute).
        with(Yast::Path.new(".target.bash_output"), /wicked show.+|grep pref-src/).
        and_return("stdout" => File.read(wicked_output_path), "exit" => 0)
      expect(Yast::Stage).to receive(:initial).and_return(true)

      expect(subject.getHostid).to eq(Yast::IP.ToHex("192.168.100.218"))
    end

    it "returns fix DEFAULT_IP in hex format (normal Stage)" do
      expect(Yast::Stage).to receive(:initial).and_return(false)

      expect(subject.getHostid).to eq(Yast::IP.ToHex(Yast::AutoInstallRulesClass::DEFAULT_IP))
    end

    it "returns nil if wicked does not find IP address" do
      expect(Yast::Stage).to receive(:initial).and_return(true)
      expect(Yast::SCR).to receive(:Execute).
        with(Yast::Path.new(".target.bash_output"), /wicked show.+|grep pref-src/).
        and_return("stderr" => "error from wicked", "exit" => 1)

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

  describe "#getNetwork" do
    before do
      allow(Yast::Stage).to receive(:initial).and_return(initial)
    end

    context "in initial stage" do
      let(:hostaddress) { "10.163.2.8" }
      let(:initial) { true }
      let(:wicked_output) { { "stdout" => wicked_content, "exit" => 0 } }
      let(:wicked_content) do
        File.read(File.join(root_path, "test", "fixtures", "network", "wicked.out"))
      end

      before do
        allow(subject).to receive(:hostaddress).and_return(hostaddress)
        allow(Yast::SCR).to receive(:Execute).
          with(Yast::Path.new(".target.bash_output"), /wicked show/).
          and_return(wicked_output)
      end

      context "the host address is known to wicked" do
        it "returns the network for the system's hostaddress" do
          expect(subject.getNetwork).to eq("10.163.2.0")
        end
      end

      context "the host address is unknown to wicked" do
        let(:hostaddress) { "10.163.2.9" }

        it "returns nil" do
          expect(subject.getNetwork).to be_nil
        end
      end

      context "wicked fails" do
        let(:wicked_output) { { "stderr" => "some error from wicked", "stdout" => "", "exit" => 1 } }

        it "returns nil" do
          expect(subject.getNetwork).to be_nil
        end
      end
    end

    context "not in initial stage" do
      let(:initial) { false }

      it "returns fixed DEFAULT_NETWORK" do
        expect(subject.getNetwork).to eq(Yast::AutoInstallRulesClass::DEFAULT_NETWORK)
      end
    end
  end
end
