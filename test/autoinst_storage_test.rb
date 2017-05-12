#!/usr/bin/env rspec

require_relative "test_helper"
Yast.import "AutoinstStorage"

describe Yast::AutoinstStorage do
  subject { Yast::AutoinstStorage }

  describe "#Import" do
    let(:proposal_settings) { double("proposal_settings") }
    let(:proposal) { double("proposal", propose: nil, proposed?: true) }
    let(:storage_manager) { double("storage_manager") }

    before do
      allow(Y2Storage::StorageManager).to receive(:instance)
        .and_return(storage_manager)
      allow(Y2Storage::Proposal).to receive(:new)
        .and_return(proposal)
      allow(storage_manager).to receive(:proposal=)
    end

    context "when no partitioning plan is given" do
      let(:profile) { nil }

      it "sets a proposal" do
        expect(storage_manager).to receive(:proposal=).with(proposal)
        subject.Import(profile)
      end

      it "returns true" do
        expect(subject.Import(profile)).to eq(true)
      end

      context "if proposal fails" do
        before do
          allow(proposal).to receive(:proposed?).and_return(false)
        end

        it "does not set the proposal" do
          expect(storage_manager).to_not receive(:proposal=)
          subject.Import(profile)
        end

        it "returns false" do
          expect(storage_manager).to_not receive(:proposal=)
          subject.Import(profile)
        end
      end
    end

    context "when profile contains an empty set of partitions" do
      let(:profile) { [] }

      it "sets a proposal" do
        expect(storage_manager).to receive(:proposal=).with(proposal)
        subject.Import(profile)
      end
    end

    context "when a partition plan is given" do
      let(:profile) { [{"device" => "/dev/sda"}] }

      it "does not build a proposal" do
        expect(Y2Storage::Proposal).to_not receive(:new)
        subject.Import(profile)
      end

      it "returns false" do
        expect(subject.Import(profile)).to eq(false)
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
