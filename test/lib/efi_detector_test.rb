require_relative "../test_helper"
require "autoinstall/efi_detector"

describe Y2Autoinstallation::EFIDetector do
  describe ".boot_efi?" do
    let(:efi) { true }

    context "when called in the initial Stage" do
      before do
        allow(Yast::Linuxrc).to receive(:InstallInf).with("EFI").and_return(efi)
      end

      context "and EFI is read as '1' from the Install.inf file" do
        it "returns true" do
          expect(described_class.boot_efi?)
        end
      end

      context "and EFI is not read as '1' from the Install.inf file" do
        let(:efi) { false }

        it "returns false" do
          expect(described_class.boot_efi?)
        end
      end
    end

    context "when called in normal Mode" do
      before do
        allow(Dir).to receive(:exist?)
      end

      described_class.const_get("EFI_VARS_DIRS").each do |dir|
        it "returns true if '#{dir}' exists" do
          expect(Dir).to receive(:exist?).with(dir).and_return(true)
          expect(described_class.boot_efi?).to eq(true)
        end
      end

      it "returns false otherwise" do
        described_class.const_get("EFI_VARS_DIRS").each do |dir|
          allow(Dir).to receive(:exist?).with(dir).and_return(false)
        end

        expect(described_class.boot_efi?).to eq(false)
      end
    end
  end
end
