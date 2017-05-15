#!/usr/bin/env rspec

require_relative "test_helper"

# storage-ng
Yast.import "AutoinstGeneral"
Yast.import "Profile"

describe "Yast::AutoinstGeneral" do
  subject { Yast::AutoinstGeneral }

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

        expect(Yast::SCR).to receive(:Execute).with(
          path(".target.bash"),
          "/usr/sbin/ntpdate -b #{Yast::AutoinstGeneral.mode["ntp_sync_time_before_installation"]}"
        ).and_return(0)

        expect(Yast::SCR).to receive(:Execute).with(path(".target.bash"), "/sbin/hwclock --systohc")
          .and_return(0)

        subject.Write()
      end
    end

    context "when no NTP server is set" do
      let(:profile) { {} }

      it "does not sync hardware time if no ntp server is set" do
        subject.Import(profile)
        expect(Yast::SCR).not_to receive(:Execute)
          .with(path(".target.bash"), /hwclock/)
        subject.Write()
      end

      it "sets multipath" do
        expect(Yast::AutoinstStorage).to receive(:set_multipathing)
        subject.Write
      end
    end
  end

  describe "#Import" do
    context "when multipath is enabled" do
      let(:profile) do
        { "storage" => { "start_multipath" => true } }
      end

      it "sets multipath"
    end

    context "when multipath is not enabled" do
      it "does not set multipath"
    end

    context "when btrfs default subvolume name is set" do
      let(:profile) do
        { "storage" => { "btrfs_set_default_subvolume_name" => "@@" } }
      end

      it "sets the default subvolume"
    end

    context "when btrfs default subvolume name is not set" do
      it "uses the default name"
    end

    context "when partitiong alignment is defined" do
      let(:profile) do
        { "storage" => { "partition_alignment" => "align_optimal" } }
      end

      it "sets partitiong alignment"
    end
  end

  describe "#Export" do
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
      subject.Import(profile)
    end

    it "exports storage settings" do
      expect(subject.Export).to include("storage" => profile["storage"])
    end

    context "when the old 'btrfs_set_default_subvolume_name' is used" do
      let(:profile) do
        { "storage" => { "btrfs_set_default_subvolume_name" => "@" } }
      end

      it "exports that option renamed to 'btrfs_default_subvolume'" do
        expect(subject.Export).to include("storage" => { "btrfs_default_subvolume" => "@" })
      end
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

    context "when btrfs default subvolume name is different from the default" do
      it "includes btrfs_set_default_subvolume_name"
    end
  end
end
