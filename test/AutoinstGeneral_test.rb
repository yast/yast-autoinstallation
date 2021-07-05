#!/usr/bin/env rspec

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

        expect(Yast::SCR).to_not receive(:Execute)
          .with(path(".target.bash"), "/sbin/hwclock --systohc")

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

    context "when there are no storage settings" do
      let(:profile) do
        {
          "storage" => {},
          "mode" => { "confirm" => false }
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
  end
end
