#!/usr/bin/env rspec

require_relative "test_helper"

# storage-ng
=begin
Yast.import "AutoInstall"
=end

describe "Yast::AutoInstall" do
  # storage-ng
  before :all do
    skip("pending of storage-ng")
  end

  subject { Yast::AutoInstall }

  describe "#pkg_gpg_check" do
    let(:data) { { "CheckPackageResult" => Yast::PkgGpgCheckHandler::CHK_OK } }
    let(:profile) { {} }
    let(:checker) { double("checker") }

    before do
      allow(Yast::Profile).to receive(:current).and_return(profile)
      allow(Yast::PkgGpgCheckHandler).to receive(:new).with(data, profile).and_return(checker)
      allow(checker).to receive(:accept?).and_return(accept?)
    end

    context "when PkgGpgCheckHandler#accept? returns true" do
      let(:accept?) { true }

      it "returns 'I' (ignore)" do
        expect(subject.pkg_gpg_check(data)).to eq("I")
      end
    end

    context "when PkgGpgCheckHandler#accept? returns false" do
      let(:accept?) { false }

      it "returns a blank string" do
        expect(subject.pkg_gpg_check(data)).to eq("")
      end
    end
  end
end
