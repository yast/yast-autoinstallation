#!/usr/bin/env rspec

# stub to avoid ntpclient build dependency
module Yast
  class NtpClient
    def self.sync_once(server)
      0
    end
  end
end

require_relative "test_helper"

Yast.import "AutoinstGeneral"
Yast.import "Profile"

describe "Yast::AutoinstGeneral" do
  subject { Yast::AutoinstGeneral }

  let(:profile) do
    {
      "storage"            => { "start_multipath" => true },
      "mode"               => { "confirm" => false },
      "signature-handling" => { "import_gpg_key" => true },
      "ask-list"           => ["ask1"],
      "proposals"          => ["proposal1"]
    }
  end

  before do
    allow(Yast).to receive(:import).and_call_original
    allow(Yast).to receive(:import).with("FileSystems").and_return(nil)
  end

  describe "#Write" do
    before do
      allow(Yast::AutoinstStorage).to receive(:Write)
    end

    context "when a NTP server is set" do
      let(:profile) do
        { "mode" => { "ntp_sync_time_before_installation" => "ntp.suse.de" } }
      end

      it "syncs hardware time" do
        subject.Import(profile)

        expect(Yast::NtpClient).to receive(:sync_once).with("ntp.suse.de").and_return(0)

        expect(Yast::SCR).to receive(:Execute).with(path(".target.bash"), "/sbin/hwclock --systohc")
          .and_return(0)

        subject.Write()
      end

      it "does not sync hardware time if ntp sync failed" do
        subject.Import(profile)

        expect(Yast::NtpClient).to receive(:sync_once).with("ntp.suse.de").and_return(1)

        expect(Yast::SCR).to_not receive(:Execute).with(path(".target.bash"), "/sbin/hwclock --systohc")

        subject.Write()
      end
    end

    context "when no NTP server is set" do
      let(:profile) { {} }

      it "does not sync hardware time" do
        subject.Import(profile)
        expect(Yast::SCR).not_to receive(:Execute)
          .with(path(".target.bash"), /hwclock/)
        subject.Write()
      end
    end
  end

  describe "#Import" do
    it "imports storage settings" do
      expect(Yast::AutoinstStorage).to receive(:import_general_settings)
        .with(profile["storage"])
      subject.Import(profile)
    end

    it "imports mode settings" do
      subject.Import(profile)
      expect(subject.mode).to eq(profile["mode"])
    end

    it "imports signature_handling settings" do
      subject.Import(profile)
      expect(subject.signature_handling).to eq(profile["signature-handling"])
    end

    it "imports asks list" do
      subject.Import(profile)
      expect(subject.askList).to eq(profile["ask-list"])
    end

    it "imports proposals list" do
      subject.Import(profile)
      expect(subject.proposals).to eq(profile["proposals"])
    end

    describe "missing values" do
      let(:profile) { {} }

      it "sets mode settings as a empty hash" do
        subject.Import(profile)
        expect(subject.mode).to eq({})
      end

      it "sets signature handling settings as an empty hash" do
        subject.Import(profile)
        expect(subject.signature_handling).to eq({})
      end

      it "sets asks list as an empty array" do
        subject.Import(profile)
        expect(subject.askList).to eq([])
      end

      it "sets proposals as an empty array" do
        subject.Import(profile)
        expect(subject.proposals).to eq([])
      end
    end
  end

  describe "#Export" do
    before do
      subject.Import(profile)
    end

    it "exports storage settings" do
      expect(subject.Export).to include("storage" => profile["storage"])
    end

    it "exports mode settings" do
      expect(subject.Export).to include("mode" => profile["mode"])
    end

    it "exports signature-handling settings" do
      expect(subject.Export).to include("signature-handling" => profile["signature-handling"])
    end

    it "exports ask-list settings" do
      expect(subject.Export).to include("ask-list" => profile["ask-list"])
    end

    it "exports proposals settings" do
      expect(subject.Export).to include("proposals" => profile["proposals"])
    end
  end
end
