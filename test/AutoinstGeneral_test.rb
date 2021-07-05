#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "AutoinstGeneral"
Yast.import "Profile"

describe "Yast::AutoinstGeneral" do
  subject { Yast::AutoinstGeneral }

  let(:profile) do
    {
      "storage"            => { "start_multipath" => true },
      "mode"               => { "confirm" => true },
      "signature-handling" => { "import_gpg_key" => true },
      "ask-list"           => ["ask1"],
      "proposals"          => ["proposal1"]
    }
  end

  before do
    allow(Yast).to receive(:import).and_call_original
    allow(Yast).to receive(:import).with("FileSystems").and_return(nil)
  end

  describe "#main" do
    let(:second_stage) { false }
    let(:imported_profile) { { "general" => general_settings } }
    let(:general_settings) { { "mode" => true } }

    before do
      allow(Yast::Stage).to receive(:cont).and_return(second_stage)
    end

    context "on first stage" do
      let(:second_stage) { false }

      it "does not try to import the profile" do
        expect(subject).to_not receive(:Import)
        subject.main
      end

      it "does not set the signatures handling callbacks" do
        expect(subject).to_not receive(:SetSignatureHandling)
        subject.main
      end
    end

    context "on second stage" do
      let(:second_stage) { true }

      before do
        allow(Yast::Profile).to receive(:current).and_return(imported_profile)
      end

      context "and the profile contains a 'general' section" do
        it "imports the profile" do
          expect(subject).to receive(:Import).with(general_settings)
          subject.main
        end
      end

      context "and the profile does not contain a 'general' section" do
        let(:general_settings) { {} }

        it "does not try to import the profile" do
          expect(subject).to_not receive(:Import)
          subject.main
        end
      end

      it "sets the signatures handling callbacks" do
        expect(subject).to receive(:SetSignatureHandling)
        subject.main
      end
    end
  end

  describe "#Write" do
    before do
      allow(Yast::AutoinstStorage).to receive(:Write)
      subject.Import(profile)
    end

    context "when a NTP server is set" do
      let(:profile) do
        { "mode" => { "ntp_sync_time_before_installation" => "ntp.suse.de" } }
      end

      it "syncs hardware time" do
        expect(Yast::NtpClient).to receive(:sync_once).with("ntp.suse.de").and_return(0)

        expect(Yast::SCR).to receive(:Execute).with(path(".target.bash"), "/sbin/hwclock --systohc")
          .and_return(0)

        subject.Write
      end

      it "does not sync hardware time if ntp sync failed" do
        expect(Yast::NtpClient).to receive(:sync_once).with("ntp.suse.de").and_return(1)

        expect(Yast::SCR).to_not receive(:Execute)
          .with(path(".target.bash"), "/sbin/hwclock --systohc")

        expect(Yast::Report).to receive(:Error)

        subject.Write
      end
    end

    context "when no NTP server is set" do
      let(:profile) { {} }

      it "does not sync hardware time" do
        subject.Import(profile)
        expect(Yast::SCR).not_to receive(:Execute)
          .with(path(".target.bash"), /hwclock/)
        subject.Write
      end
    end

    context "mode options" do
      context "when mode options are set" do
        let(:profile) do
          {
            "mode" => {
              "confirm" => true, "second_stage" => true, "halt" => true, "rebootmsg" => true
            }
          }
        end

        it "saves mode options" do
          expect(Yast::AutoinstConfig).to receive(:second_stage=).with(true)
          expect(Yast::AutoinstConfig).to receive(:Halt=).with(true)
          expect(Yast::AutoinstConfig).to receive(:RebootMsg=).with(true)
          subject.Write
        end
      end

      context "when mode options are not set" do
        let(:profile) { {} }

        it "saves default values" do
          expect(Yast::AutoinstConfig).to_not receive(:second_stage=)
          expect(Yast::AutoinstConfig).to receive(:Halt=).with(false)
          expect(Yast::AutoinstConfig).to receive(:RebootMsg=).with(false)
          subject.Write
        end
      end

      it "sets signature handling callbacks" do
        expect(subject).to receive(:SetSignatureHandling)
        subject.Write
      end
    end

    context "when 'forceboot' is not set" do
      it "does not set the kexec_reboot option in the product control" do
        expect(Yast::ProductFeatures).to_not receive(:SetBooleanFeature)
          .with("globals", "kexec_reboot", anything)
        subject.Write
      end
    end

    context "when 'forceboot' is set to 'false'" do
      let(:profile) { { "mode" => { "forceboot" => false } } }

      it "sets the kexec_reboot option in the product control to 'false'" do
        expect(Yast::ProductFeatures).to_not receive(:SetBooleanFeature)
          .with("globals", "kexec_reboot", false)
        subject.Write
      end
    end

    context "when 'forceboot' is set to 'true'" do
      let(:profile) { { "mode" => { "forceboot" => true } } }

      it "sets the kexec_reboot option in the product control to 'true'" do
        expect(Yast::ProductFeatures).to_not receive(:SetBooleanFeature)
          .with("globals", "kexec_reboot", true)
        subject.Write
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

    context "when there are no storage settings" do
      let(:profile) do
        {
          "storage" => {},
          "mode"    => { "confirm" => false }
        }
      end

      it "does not export storage settings" do
        expect(subject.Export.keys).to_not include("storage")
      end
    end

    it "exports mode settings" do
      expect(subject.Export).to include("mode" => profile["mode"])
    end

    it "exports signature-handling settings" do
      expect(subject.Export).to include("signature-handling" => profile["signature-handling"])
    end

    context "when there are no signature-handling settings" do
      let(:profile) do
        { "signature-handling" => {} }
      end

      it "does not export the signature handling settings" do
        expect(subject.Export.keys).to_not include("signature-handling")
      end
    end

    it "exports ask-list settings" do
      expect(subject.Export).to include("ask-list" => profile["ask-list"])
    end

    context "when there are no ask-list settings" do
      let(:profile) do
        { "ask-list" => [] }
      end

      it "does not export the ask-list settings" do
        expect(subject.Export.keys).to_not include("ask-list")
      end
    end

    it "exports proposals settings" do
      expect(subject.Export).to include("proposals" => profile["proposals"])
    end
  end

  RSpec.shared_examples "sets callback" do |option, cb_map = {}|
    let(:signature_handling) { {} }

    default_cb = option.split("_").map(&:capitalize).join # e.g., "AcceptUnsignedFile"
    cb = "Callback#{default_cb}" # e.g., "CallbackAcceptUnsignedFile"

    before do
      subject.Import("signature-handling" => signature_handling)
    end

    context cb do
      context "when '#{option}' is not set" do
        it "sets '#{default_cb}' as the default handler" do
          expect(Yast::Pkg).to receive(cb) do |ref|
            expect(ref.remote_method)
              .to eq(Yast::SignatureCheckCallbacks.method(default_cb))
          end
          subject.SetSignatureHandling
        end
      end

      cb_map.each do |cb_name, value|
        context "when '#{option}' is set to '#{value}'" do
          let(:signature_handling) do
            { option => value }
          end

          it "sets the '#{cb_name}' callback" do
            expect(Yast::Pkg).to receive(cb).ordered.with(any_args)
            expect(Yast::Pkg).to receive(cb).ordered do |ref|
              expect(ref.remote_method).to eq(Yast::AutoInstall.method(cb_name))
            end
            subject.SetSignatureHandling
          end
        end
      end
    end
  end

  describe "#SetSignatureHandling" do
    before do
      subject.Import("signature-handling" => signature_handling)
    end

    include_examples "sets callback", "accept_unsigned_file",
      callbackTrue_boolean_string_integer:  true,
      callbackFalse_boolean_string_integer: false

    include_examples "sets callback", "accept_file_without_checksum",
      callbackTrue_boolean_string:  true,
      callbackFalse_boolean_string: false

    include_examples "sets callback", "accept_verification_failed",
      callbackTrue_boolean_string_map_integer:  true,
      callbackFalse_boolean_string_map_integer: false

    include_examples "sets callback", "accept_verification_failed",
      callbackTrue_boolean_string_map_integer:  true,
      callbackFalse_boolean_string_map_integer: false

    include_examples "sets callback", "accept_unknown_gpg_key",
      callbackTrue_boolean_string_string_integer:  true,
      callbackFalse_boolean_string_string_integer: false

    include_examples "sets callback", "accept_wrong_digest",
      callbackTrue_boolean_string_string_string:  true,
      callbackFalse_boolean_string_string_string: false

    include_examples "sets callback", "accept_unknown_digest",
      callbackTrue_boolean_string_string_string:  true,
      callbackFalse_boolean_string_string_string: false

    include_examples "sets callback", "import_gpg_key",
      callbackTrue_boolean_map_integer:  true,
      callbackFalse_boolean_map_integer: false

    include_examples "sets callback", "trusted_key_added",
      callback_void_map: ["key"]

    include_examples "sets callback", "trusted_key_removed",
      callback_void_map: ["key"]
  end

  describe "#Summary" do
    it "includes information about installation confirmation and signature handling" do
      summary = subject.Summary
      expect(summary).to include("Confirm installation?")
      expect(summary).to include("Signature Handling")
    end

    context "when signature handling checks are disabled" do
      before do
        subject.Import(
          "signature-handling" => {
            "accept_unsigned_file"         => true,
            "accept_file_without_checksum" => true,
            "accept_verification_failed"   => true,
            "accept_unknown_gpg_key"       => true,
            "import_gpg_key"               => true
          }
        )
      end

      it "includes signature settings values" do
        summary = subject.Summary
        expect(summary).to include("Accepting unsigned files")
        expect(summary).to include("Accepting files without a checksum")
        expect(summary).to include("Accepting failed verifications")
        expect(summary).to include("Accepting unknown GPG keys")
        expect(summary).to include("Importing new GPG keys")
      end
    end

    context "when signature handling checks are not disabled" do
      before do
        subject.Import(
          "signature-settings" => {
            "accept_unsigned_file"         => false,
            "accept_file_without_checksum" => false,
            "accept_verification_failed"   => false,
            "accept_unknown_gpg_key"       => false,
            "import_gpg_key"               => false
          }
        )
      end

      it "includes signature settings values" do
        summary = subject.Summary
        expect(summary).to include("Not accepting unsigned files")
        expect(summary).to include("Not accepting files without a checksum")
        expect(summary).to include("Not accepting failed verifications")
        expect(summary).to include("Not accepting unknown GPG Keys")
        expect(summary).to include("Not importing new GPG Keys")
      end
    end
  end

  describe "#processes_to_wait" do
    it "returns array" do
      subject.Import({})

      expect(subject.processes_to_wait("test")).to be_a(::Array)
    end

    it "does not crash if import is not called" do
      subject = Yast::AutoinstGeneralClass.new
      subject.main

      expect(subject.processes_to_wait("Test")).to be_a(::Array)
    end
  end
end
