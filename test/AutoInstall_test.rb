#!/usr/bin/env rspec

require_relative "test_helper"
require "installation/autoinst_issues"
require "autoinstall/dialogs/question"
require "installation/autoinst_profile/section_with_attributes"

Yast.import "AutoInstall"
Yast.import "UI"

module Test
  module AutoinstProfile
    class FirewallSection < ::Installation::AutoinstProfile::SectionWithAttributes
      def self.new_from_hashes(_hash)
        new
      end
    end
  end
end

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
      subject.main
      allow(Yast::Report).to receive(:Export).and_return(report_settings)
      allow(Test::AutoinstProfile::FirewallSection).to receive(:new_from_hashes)
        .and_return(fw_section)
    end

    let(:report_settings) do
      {
        "errors"   => { "log" => true, "show" => false, "timeout" => 0 },
        "warnings" => { "log" => true, "show" => true, "timeout" => 0 }
      }
    end

    let(:fw_section) { Test::AutoinstProfile::FirewallSection.new }

    context "when no issue has been found" do
      it "returns true" do
        expect(subject.valid_imported_values).to eq(true)
      end
    end

    context "when an issue has been found" do
      it "shows a popup" do
        subject.issues_list.add(
          ::Installation::AutoinstIssues::InvalidValue,
          fw_section, "FW_DEV_INT", "1",
          _("Is not supported anymore.")
        )
        expect_any_instance_of(Y2Autoinstallation::Dialogs::Question).to receive(:run)
          .and_return(:ok)
        expect(subject.valid_imported_values).to eq(true)
      end
    end

    context "when a fatal issue is found" do
      it "shows a popup eve if error reporting is disabled" do
        subject.issues_list.add(
          ::Installation::AutoinstIssues::InvalidValue,
          fw_section, "FW_DEV_INT", "X",
          _("Is not supported anymore."), :fatal
        )
        expect_any_instance_of(Y2Autoinstallation::Dialogs::Question).to receive(:run)
          .and_return(:ok)
        expect(subject.valid_imported_values).to eq(true)
      end
    end
  end
end
