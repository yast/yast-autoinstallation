#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "AutoinstGeneral"
Yast.import "Profile"

describe Yast::AutoinstGeneral do
  FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures')

  let(:default_subvol) { "@" }
  let(:filesystems) do
    double("filesystems",
      default_subvol: default_subvol, read_default_subvol_from_target: default_subvol)
  end

  before do
    allow(Yast).to receive(:import).and_call_original
    allow(Yast).to receive(:import).with("FileSystems").and_return(nil)
    stub_const("Yast::FileSystems", filesystems)
  end

  describe "#ntp syncing in Write call" do
    let(:profile_sync) { File.join(FIXTURES_PATH, 'profiles', 'general_with_time_sync.xml') }
    let(:profile_no_sync) { File.join(FIXTURES_PATH, 'profiles', 'general_without_time_sync.xml') }

    it "syncing hardware time if ntp server is set" do
      Yast::Profile.ReadXML(profile_sync)
      Yast::AutoinstGeneral.Import(Yast::Profile.current["general"])

      expect(Yast::SCR).to receive(:Execute).with(
        path(".target.bash"),
        "/usr/sbin/ntpdate -b #{Yast::AutoinstGeneral.mode["ntp_sync_time_before_installation"]}").and_return(0)
      expect(Yast::SCR).to receive(:Execute).with(
        path(".target.bash"),"/sbin/hwclock --systohc").and_return(0)

      Yast::AutoinstGeneral.Write()
    end

    it "not syncing hardware time if no ntp server is set" do
      Yast::Profile.ReadXML(profile_no_sync)
      Yast::AutoinstGeneral.Import(Yast::Profile.current["general"])

      expect(Yast::SCR).not_to receive(:Execute).with(
        path(".target.bash"),"/sbin/hwclock --systohc")

      Yast::AutoinstGeneral.Write()
    end

  end

end
