#!/usr/bin/env rspec

require_relative "test_helper"
require "autoinstall/autoinst_issues"
require "autoinstall/autoinst_issues_presenter"
require "autoinstall/dialogs/question"

Yast.import "AutoInstall"
Yast.import "UI"

describe "Yast::AutoInstall" do
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

  describe "#valid_imported_values" do
    before(:each) do
      subject.issues_list = Y2Autoinstallation::AutoinstIssues::List.new
    end

    context "when no issue has been found" do
      it "returns true" do
        expect(subject.valid_imported_values).to eq(true)
      end
    end

    context "when an issue has been found" do
      it "shows a popup" do
        subject.issues_list.add(:invalid_value, "firewall", "FW_DEV_INT", "1",
                                _("Is not supported anymore."))
        expect_any_instance_of(Y2Autoinstallation::Dialogs::Question).to receive(:run).and_return(:ok)
        expect(subject.valid_imported_values).to eq(true)
      end
    end
  end
end
