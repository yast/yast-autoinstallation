#!/usr/bin/env rspec

require_relative "../test_helper"
require_relative "../../src/lib/autoinstall/pkg_gpg_check_handler"

require "yast"

Yast.import "Profile"

describe Yast::PkgGpgCheckHandler do
  subject(:handler) { Yast::PkgGpgCheckHandler.new(data, profile) }

  let(:data) do
    Yast::ProfileHash.new(
      "CheckPackageResult" => result,
      "Package"            => "dummy-package",
      "Localpath"          => "/path/to/dummy-package.rpm",
      "RepoMediaUrl"       => "http://dl.opensuse.org/repos/YaST:/Head"
    )
  end
  let(:result) { Yast::PkgGpgCheckHandler::CHK_OK }
  let(:profile) do
    Yast::ProfileHash.new("general" => { "signature-handling" => signature_handling })
  end
  let(:signature_handling) { {} }

  describe "#accept?" do
    context "when signature is OK" do
      it "returns true" do
        expect(handler.accept?).to eq(true)
      end
    end

    context "when package signature is not found" do
      let(:result) { Yast::PkgGpgCheckHandler::CHK_NOTFOUND }

      context "and is not specified whether unsigned packages are allowed or not" do
        it "returns false" do
          expect(handler.accept?).to eq(false)
        end
      end

      context "and unsigned packages are allowed" do
        let(:signature_handling) { { "accept_unsigned_file" => true } }

        it "returns true" do
          expect(handler.accept?).to eq(true)
        end
      end

      context "and unsigned packages are not allowed" do
        let(:signature_handling) { { "accept_unsigned_file" => false } }

        it "returns false" do
          expect(handler.accept?).to eq(false)
        end
      end
    end

    context "when package signature is not found but digests are valid" do
      let(:result) { Yast::PkgGpgCheckHandler::CHK_NOSIG }

      context "and is not specified whether unsigned packages are allowed or not" do
        it "returns false" do
          expect(handler.accept?).to eq(false)
        end
      end

      context "and unsigned packages are allowed" do
        let(:signature_handling) { { "accept_unsigned_file" => true } }

        it "returns true" do
          expect(handler.accept?).to eq(true)
        end
      end

      context "and unsigned packages are not allowed" do
        let(:signature_handling) { { "accept_unsigned_file" => false } }

        it "returns false" do
          expect(handler.accept?).to eq(false)
        end
      end
    end

    context "when package signature failed" do
      let(:result) { Yast::PkgGpgCheckHandler::CHK_FAIL }

      context "and is not specified whether bad signatures are allowed or not" do
        it "returns false" do
          expect(handler.accept?).to eq(false)
        end
      end

      context "and packages with bad signatures are allowed" do
        let(:signature_handling) { { "accept_verification_failed" => true } }

        it "returns true" do
          expect(handler.accept?).to eq(true)
        end
      end

      context "and unsigned packages are not allowed" do
        let(:signature_handling) { { "accept_verification_failed" => false } }

        it "returns false" do
          expect(handler.accept?).to eq(false)
        end
      end
    end

    context "when public key is not available" do
      let(:result) { Yast::PkgGpgCheckHandler::CHK_NOKEY }
      let(:key_id) { "9b7d32f2d40582e2" }
      let(:rpm_output) do
        { "exit"   => 0,
          "stdout" => "DSA/SHA1, Mon 05 Oct 2015 04:24:50 PM WEST, Key ID #{key_id}" }
      end

      before do
        cmd = format(Yast::PkgGpgCheckHandler::FIND_KEY_ID_CMD, data["Localpath"])
        allow(Yast::SCR).to receive(:Execute).with(path(".target.bash_output"), cmd)
          .and_return(rpm_output)
      end

      context "and is not specified whether unknown GPG keys are allowed or not" do
        it "returns false" do
          expect(handler.accept?).to eq(false)
        end
      end

      context "and packages with unknown GPG keys are allowed" do
        let(:signature_handling) { { "accept_unknown_gpg_key" => true } }

        it "returns true" do
          expect(handler.accept?).to eq(true)
        end
      end

      context "and all packages with unknown GPG keys are allowed" do
        # Using '<all>' element in profile instead of just 'true'.
        let(:signature_handling) { { "accept_unknown_gpg_key" => { "all" => true } } }

        it "returns true" do
          expect(handler.accept?).to eq(true)
        end
      end

      context "and this specific key ID is allowed" do
        let(:signature_handling) do
          { "accept_unknown_gpg_key" =>
                                        { "all"  => false,
                                          "keys" => [key_id] } }
        end

        it "returns true" do
          expect(handler.accept?).to eq(true)
        end
      end

      context "and this specific key ID is not allowed" do
        let(:signature_handling) do
          { "accept_unknown_gpg_key" =>
                                        { "all"  => false,
                                          "keys" => ["0000000000000000"] } }
        end

        it "returns false" do
          expect(handler.accept?).to eq(false)
        end
      end

      context "and package key ID could not be read" do
        let(:rpm_output) { { "exit" => 1, "stdout" => "" } }
        let(:signature_handling) do
          { "accept_unknown_gpg_key" =>
                                        { "all"  => false,
                                          "keys" => [key_id] } }
        end

        it "returns false" do
          expect(handler.accept?).to eq(false)
        end
      end
    end

    context "when GPG key is non trusted" do
      let(:result) { Yast::PkgGpgCheckHandler::CHK_NOTTRUSTED }
      let(:key_id) { "9b7d32f2d40582e2" }
      let(:rpm_output) do
        { "exit"   => 0,
          "stdout" => "DSA/SHA1, Mon 05 Oct 2015 04:24:50 PM WEST, Key ID #{key_id}" }
      end

      before do
        cmd = format(Yast::PkgGpgCheckHandler::FIND_KEY_ID_CMD, data["Localpath"])
        allow(Yast::SCR).to receive(:Execute).with(path(".target.bash_output"), cmd)
          .and_return(rpm_output)
      end

      context "and is not specified whether non trusted GPG keys are allowed or not" do
        it "returns false" do
          expect(handler.accept?).to eq(false)
        end
      end

      context "and packages with non trusted keys are allowed" do
        let(:signature_handling) { { "accept_non_trusted_gpg_key" => true } }

        it "returns true" do
          expect(handler.accept?).to eq(true)
        end
      end

      context "and all packages with non trusted keys are allowed" do
        # Using '<all>' element in profile instead of just 'true'.
        let(:signature_handling) { { "accept_non_trusted_gpg_key" => { "all" => true } } }

        it "returns true" do
          expect(handler.accept?).to eq(true)
        end
      end

      context "and this specific key ID is allowed" do
        let(:signature_handling) do
          { "accept_non_trusted_gpg_key" =>
                                            { "all"  => false,
                                              "keys" => [key_id] } }
        end

        it "returns true" do
          expect(handler.accept?).to eq(true)
        end
      end

      context "and this specific key ID is not allowed" do
        let(:signature_handling) do
          { "accept_non_trusted_gpg_key" =>
                                            { "all"  => false,
                                              "keys" => ["0000000000000000"] } }
        end

        it "returns false" do
          expect(handler.accept?).to eq(false)
        end
      end

      context "and key ID could not be read" do
        let(:signature_handling) do
          { "accept_non_trusted_gpg_key" =>
                                            { "all"  => false,
                                              "keys" => [key_id] } }
        end
        let(:rpm_output) { { "exit" => 1, "stdout" => "" } }

        it "returns false" do
          expect(handler.accept?).to eq(false)
        end
      end
    end

    context "when package could not be open" do
      let(:result) { Yast::PkgGpgCheckHandler::CHK_ERROR }

      it "returns false" do
        expect(handler.accept?).to eq(false)
      end
    end

    context "when the add-on has specific settings" do
      let(:result) { Yast::PkgGpgCheckHandler::CHK_NOTFOUND }

      let(:profile) do
        Yast::ProfileHash.new(
          "general" => {
            "signature-handling" => {
              "accept_unsigned_file"   => true,
              "accept_unknown_gpg_key" => true
            }
          },
          "add-on"  => {
            "add_on_products" => [
              {
                "media_url"          => "http://dl.opensuse.org/repos/YaST:/Head",
                "name"               => "yast_head",
                "signature-handling" => { "accept_unsigned_file" => false }
              }
            ]
          }
        )
      end

      it "honors the add-on settings" do
        expect(handler.accept?).to eq(false)
      end

      it "honors general settings which are not overridden" do
        gpg_handler = Yast::PkgGpgCheckHandler.new(
          data.merge("CheckPackageResult" => Yast::PkgGpgCheckHandler::CHK_NOKEY), profile
        )
        expect(gpg_handler.accept?).to eq(true)
      end
    end
  end
end
