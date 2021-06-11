#!/usr/bin/env rspec

require_relative "test_helper"
require "y2storage"

Yast.import "AutoinstStorage"

describe Yast::AutoinstStorage do
  subject { Yast::AutoinstStorage }

  describe "#Import" do
    let(:storage_proposal) do
      instance_double(
        Y2Autoinstallation::StorageProposal, valid?: valid?, issues_list: issues_list
      )
    end
    let(:issues_dialog) { instance_double(Y2Autoinstallation::Dialogs::Question, run: :abort) }
    let(:issues_list) { ::Installation::AutoinstIssues::List.new }
    let(:profile_section) { Y2Storage::AutoinstProfile::PartitionSection.new_from_hashes({}) }
    let(:valid?) { true }
    let(:errors_settings) { { "show" => false, "timeout" => 10 } }
    let(:warnings_settings) { { "show" => true, "timeout" => 5 } }
    let(:settings) { [{ "device" => "/dev/sda" }] }
    let(:ask_settings) { [{ "device" => "ask" }] }
    let(:preprocessor) do
      instance_double(Y2Autoinstallation::PartitioningPreprocessor, run: settings)
    end
    let(:probed_devicegraph) do
      instance_double(Y2Storage::Devicegraph, empty?: false)
    end
    let(:storage_manager) do
      instance_double(Y2Storage::StorageManager, probed: probed_devicegraph)
    end

    before do
      allow(Y2Autoinstallation::StorageProposal).to receive(:new)
        .and_return(storage_proposal)
      allow(Y2Autoinstallation::Dialogs::Question).to receive(:new)
        .and_return(issues_dialog)
      allow(storage_proposal).to receive(:save)
      allow(Y2Autoinstallation::PartitioningPreprocessor).to receive(:new)
        .and_return(preprocessor)
      allow(Y2Storage::StorageManager).to receive(:instance).and_return(storage_manager)
    end

    around do |example|
      old_settings = Yast::Report.Export
      Yast::Report.Import("warnings" => warnings_settings, "errors" => errors_settings)
      example.run
      Yast::Report.Import(old_settings)
    end

    it "creates a proposal" do
      expect(Y2Autoinstallation::StorageProposal).to receive(:new)
      subject.Import({})
    end

    it "preprocess given settings" do
      expect(preprocessor).to receive(:run).with(ask_settings)
      expect(Y2Autoinstallation::StorageProposal).to receive(:new)
        .with(settings, anything)
        .and_return(storage_proposal)
      subject.Import([{ "device" => "ask" }])
    end

    context "when no partitioning configuration is given" do
      it "considers an empty 'partitioning' section" do
        expect(preprocessor).to receive(:run).with([])
        expect(Y2Autoinstallation::StorageProposal).to receive(:new).with(settings, anything)
        subject.Import(nil)
      end
    end

    context "when settings are not preprocessed successfully" do
      let(:settings) { nil }

      it "returns false" do
        expect(subject.Import({})).to eq(false)
      end
    end

    context "when the proposal is valid" do
      let(:valid?) { true }

      it "returns true" do
        expect(subject.Import({})).to eq(true)
      end

      it "saves the proposal" do
        expect(storage_proposal).to receive(:save)
        subject.Import({})
      end
    end

    context "when the proposal contains fatal issues" do
      let(:valid?) { false }

      before do
        issues_list.add(Y2Storage::AutoinstIssues::MissingRoot)
      end

      it "shows errors to the user without timeout" do
        expect(Y2Autoinstallation::Dialogs::Question).to receive(:new)
          .with("Partitioning issues", /Important issues/, timeout: 0, buttons_set: :abort)
          .and_return(issues_dialog)
        expect(issues_dialog).to receive(:run)
        subject.Import({})
      end

      it "returns false" do
        allow(issues_dialog).to receive(:run).and_return(:abort)
        expect(subject.Import({})).to eq(false)
      end

      context "and errors logging is enabled" do
        let(:errors_settings) { { "log" => true } }

        it "logs the error" do
          expect(subject.log).to receive(:error)
            .with(/Important issues/)
          subject.Import({})
        end
      end

      context "and errors logging is disabled" do
        let(:errors_settings) { { "log" => false } }

        it "does not log the error" do
          expect(subject.log).to_not receive(:error)
            .with(/Important issues/)
          subject.Import({})
        end
      end
    end

    context "when the proposal contains non fatal issues" do
      let(:valid?) { false }
      let(:continue) { true }

      before do
        issues_list.add(Y2Storage::AutoinstIssues::InvalidValue,
          profile_section, :size, "auto")
        allow(subject.log).to receive(:warn).and_call_original
      end

      context "and warnings reporting is enabled" do
        it "asks the user for confirmation" do
          expect(Y2Autoinstallation::Dialogs::Question).to receive(:new)
            .with("Partitioning issues", /Minor issues/, timeout: 5, buttons_set: :question)
            .and_return(issues_dialog)
          expect(issues_dialog).to receive(:run)
          subject.Import({})
        end

        context "and the user confirms the proposal" do
          before do
            allow(issues_dialog).to receive(:run).and_return(:ok)
          end

          it "returns true" do
            expect(subject.Import({})).to eq(true)
          end
        end

        context "and the user dismisses the proposal" do
          before do
            allow(issues_dialog).to receive(:run).and_return(:abort)
          end

          it "returns false" do
            expect(subject.Import({})).to eq(false)
          end
        end
      end

      context "and warnings reporting is disabled" do
        let(:warnings_settings) { { "show" => false } }

        it "returns true" do
          expect(subject.Import({})).to eq(true)
        end
      end

      context "and warnings logging is enabled" do
        let(:warnings_settings) { { "log" => true } }

        it "logs the warning" do
          expect(subject.log).to receive(:warn)
            .with(/Minor issues/)
          subject.Import({})
        end
      end

      context "and warnings logging is disabled" do
        let(:warnings_settings) { { "log" => false } }

        it "does not log the warning" do
          expect(subject.log).to_not receive(:warn)
            .with(/Some minor problems/)
          subject.Import({})
        end
      end
    end
  end

  describe "#import_general_settings" do
    let(:profile) do
      { "proposal" => proposal }
    end
    let(:proposal) do
      { "lvm"                 => true,
        "windows_delete_mode" => :all,
        "linux_delete_mode"   => :all,
        "other_delete_mode"   => :all,
        "resize_windows"      => true,
        "encryption_password" => "12345678" }
    end
    let(:delete_resize_configurable) { true }
    let(:proposal_settings) do
      Y2Storage::ProposalSettings.new.tap do |settings|
        settings.windows_delete_mode = :ondemand
        settings.delete_resize_configurable = delete_resize_configurable
      end
    end

    before do
      allow(Y2Storage::ProposalSettings).to receive(:new_for_current_product)
        .and_return(proposal_settings)
    end

    it "imports proposal settings from the profile" do
      subject.import_general_settings(profile)
      expect(subject.proposal_settings.lvm).to eq(true)
    end

    it "does not log any warning" do
      expect(subject.log).to_not receive(:warn)
      subject.import_general_settings(profile)
    end

    context "when a value is not set in the profile" do
      let(:proposal) do
        { "lvm" => true }
      end

      it "keeps the product default" do
        subject.import_general_settings(profile)
        expect(subject.proposal_settings.windows_delete_mode).to eq(:ondemand)
      end
    end

    context "when no value is set in the profile" do
      let(:proposal) { nil }

      it "keeps the product defaults" do
        subject.import_general_settings(profile)
        expect(subject.proposal_settings.windows_delete_mode).to eq(:ondemand)
      end
    end

    context "when unknown proposal settings are specified" do
      let(:proposal) { { "foo" => "bar" } }

      it "logs a warning" do
        expect(subject.log).to receive(:warn).with(/Ignoring.*foo/)
        subject.import_general_settings(profile)
      end
    end

    context "when the product does not allow to configure resizing or delete modes" do
      let(:delete_resize_configurable) { false }
      let(:proposal) do
        {
          "windows_delete_mode" => :all,
          "linux_delete_mode"   => :all,
          "other_delete_mode"   => :all,
          "resize_windows"      => true
        }
      end

      it "ignores related options" do
        subject.import_general_settings(profile)
        expect(subject.proposal_settings.windows_delete_mode).to eq(:ondemand)
        expect(subject.proposal_settings.linux_delete_mode).to be_nil
        expect(subject.proposal_settings.other_delete_mode).to be_nil
        expect(subject.proposal_settings.resize_windows).to be_nil
      end

      it "logs a warning" do
        expect(subject.log).to receive(:warn).with(/Ignoring.*windows_delete_mode/)
        subject.import_general_settings(profile)
      end
    end

    context "when settings are not a hash" do
      let(:profile) { "" }

      it "does not import the settings" do
        subject.import_general_settings(profile)
        expect(subject.general_settings).to be_a(Hash)
      end
    end
  end
end
