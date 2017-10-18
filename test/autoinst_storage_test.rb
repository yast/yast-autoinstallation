#!/usr/bin/env rspec

require_relative "test_helper"
Yast.import "AutoinstStorage"

describe Yast::AutoinstStorage do
  subject { Yast::AutoinstStorage }

  describe "#Import" do
    let(:storage_proposal) do
      instance_double(
        Y2Autoinstallation::StorageProposal, valid?: valid?, problems_list: problems_list
      )
    end

    let(:problems_list) { Y2Storage::AutoinstProblems::List.new }
    let(:valid?) { true }

    before do
      allow(Y2Autoinstallation::StorageProposal).to receive(:new)
        .and_return(storage_proposal)
      allow(storage_proposal).to receive(:save)
    end

    it "creates a proposal" do
      expect(Y2Autoinstallation::StorageProposal).to receive(:new)
      subject.Import({})
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

    context "when the proposal is not valid" do
      let(:valid?) { false }
      let(:continue) { true }

      before do
        allow(Yast::Report).to receive(:ErrorAnyQuestion)
          .and_return(continue)
      end

      context "and there are no fatal errors" do
        it "asks the user to continue" do
          expect(Yast::Report).to receive(:ErrorAnyQuestion)
          subject.Import({})
        end

        context "and the user decides to continue" do
          it "returns true" do
            expect(subject.Import({})).to eq(true)
          end

          it "saves the proposal" do
            expect(storage_proposal).to receive(:save)
            subject.Import({})
          end
        end

        context "and the user decides to abort" do
          let(:continue) { false }

          it "returns false" do
            expect(subject.Import({})).to eq(false)
          end

          it "does not save the proposal" do
            expect(storage_proposal).to_not receive(:save)
            subject.Import({})
          end
        end
      end

      context "and there are fatal errors" do
        before do
          problems_list.add(:missing_root)
        end

        it "returns false" do
          expect(subject.Import({})).to eq(false)
        end

        it "notifies the user" do
          expect(Yast::Popup).to receive(:LongError)
            .with(/No root partition/)
          subject.Import({})
        end

        it "does not save the proposal" do
          expect(storage_proposal).to_not receive(:save)
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
