#!/usr/bin/env rspec

require_relative "test_helper"
require "y2storage"

Yast.import "AutoinstStorage"
Yast.import "Profile"

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

    before do
      allow(Y2Autoinstallation::StorageProposal).to receive(:new)
        .and_return(storage_proposal)
      allow(Y2Autoinstallation::Dialogs::Question).to receive(:new)
        .and_return(issues_dialog)
      allow(storage_proposal).to receive(:save)
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

    context "when subvolumes are defined" do
      let(:partition_profile) { File.join(FIXTURES_PATH, 'profiles', 'subvolumes_partitions.xml') }

      it "filtering out @ subvolumes" do
        Yast::Profile.ReadXML(partition_profile)
        device = Marshal.load(Marshal.dump(Yast::Profile.current["partitioning"]))
        device.first["partitions"].first["subvolumes"].delete_if{|s| s=="@"}
        expect(Y2Autoinstallation::StorageProposal).to receive(:new)
          .with(device)
        subject.Import(Yast::Profile.current["partitioning"])
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
          .with(/Important issues/, timeout: 0, buttons_set: :abort)
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
            .with(/Minor issues/, timeout: 5, buttons_set: :question)
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

    it "overrides control file values" do
      expect(Yast::ProductFeatures).to receive(:SetOverlay)
        .with("partitioning" => profile)
      subject.import_general_settings(profile)
    end

    context "when multipath is enabled" do
      let(:profile) { { "start_multipath" => true } }

      it "sets multipath"
    end

    context "when multipath is not enabled" do
      it "does not set multipath"
    end

    context "when btrfs default subvolume name is set" do
      let(:profile) { { "btrfs_set_default_subvolume_name" => "@@" } }

      it "sets the default subvolume"
    end

    context "when btrfs default subvolume name is not set" do
      it "uses the default name"
    end

    context "when partitiong alignment is defined" do
      let(:profile) { { "partition_alignment" => "align_optimal" } }

      it "sets partitiong alignment"
    end
  end
end
