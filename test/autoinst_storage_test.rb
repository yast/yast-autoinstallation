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
    let(:issues_list) { Y2Storage::AutoinstIssues::List.new }
    let(:profile_section) { Y2Storage::AutoinstProfile::PartitionSection.new_from_hashes({}) }
    let(:valid?) { true }
    let(:errors_settings) { { "show" => false, "timeout" => 10 } }
    let(:warnings_settings) { { "show" => true, "timeout" => 5 } }
    let(:settings) { [{ "device" => "/dev/sda" }] }
    let(:ask_settings) { [{ "device" => "ask" }] }
    let(:preprocessor) { instance_double(Y2Autoinstallation::PartitioningPreprocessor, run: settings) }

    before do
      allow(Y2Autoinstallation::StorageProposal).to receive(:new)
        .and_return(storage_proposal)
      allow(Y2Autoinstallation::Dialogs::Question).to receive(:new)
        .and_return(issues_dialog)
      allow(storage_proposal).to receive(:save)
      allow(Y2Autoinstallation::PartitioningPreprocessor).to receive(:new)
        .and_return(preprocessor)
    end

    around do |example|
      old_settings = Yast::Report.Export
      Yast::Report.Import({"warnings" => warnings_settings, "errors" => errors_settings})
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
        .with(settings)
        .and_return(storage_proposal)
      subject.Import([{ "device" => "ask" }])
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
        issues_list.add(:missing_root)
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
        issues_list.add(:invalid_value, profile_section, :size, "auto")
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
    let(:profile) { { "proposal_lvm" => true } }
    let(:partitioning_features) { {"btrfs_default_subvolume" => "@" } }

    around do |example|
      old_partitioning = Yast::ProductFeatures.GetSection("partitioning")
      Yast::ProductFeatures.SetSection("partitioning", partitioning_features)
      example.call
      Yast::ProductFeatures.SetSection("partitioning", old_partitioning)
    end

    it "overrides control file values" do
      subject.import_general_settings(profile)
      expect(Yast::ProductFeatures.GetSection("partitioning")).to include("proposal_lvm" => true)
    end

    it "keeps not overriden values" do
      subject.import_general_settings(profile)
      expect(Yast::ProductFeatures.GetSection("partitioning"))
        .to include("btrfs_default_subvolume" => "@")
    end

    context "when btrfs default subvolume name is set to false" do
      let(:profile) { { "btrfs_set_default_subvolume_name" => false } }

      it "disables the btrfs default subvolume" do
        subject.import_general_settings(profile)
        expect(Yast::ProductFeatures.GetSection("partitioning"))
          .to include("btrfs_default_subvolume" => "")
      end
    end

    context "when btrfs default subvolume name is not set" do
      let(:profile) { {} }

      it "uses the default for the product" do
        subject.import_general_settings(profile)
        expect(Yast::ProductFeatures.GetSection("partitioning"))
          .to include("btrfs_default_subvolume" => "@")
      end
    end

    context "when btrfs default subvolume name is set to true" do
      let(:profile) { { "btrfs_set_default_subvolume_name" => true } }

      it "uses the default for the product" do
        subject.import_general_settings(profile)
        expect(Yast::ProductFeatures.GetSection("partitioning"))
          .to include("btrfs_default_subvolume" => "@")
      end
    end
  end
end
