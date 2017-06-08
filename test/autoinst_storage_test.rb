#!/usr/bin/env rspec

require_relative "test_helper"
Yast.import "AutoinstStorage"

describe Yast::AutoinstStorage do
  subject { Yast::AutoinstStorage }

  describe "#Import" do
    let(:storage_proposal) { instance_double(Y2Autoinstallation::StorageProposal) }

    before do
      allow(Y2Autoinstallation::StorageProposal).to receive(:new)
        .and_return(storage_proposal)
    end

    it "creates a proposal" do
      expect(storage_proposal).to receive(:propose_and_store)
        .and_return(true)
      subject.Import({})
    end

    it "returns true if proposal succeeds" do
      allow(storage_proposal).to receive(:propose_and_store)
        .and_return(true)
      expect(subject.Import({})).to eq(true)
    end

    it "returns false if proposal fails" do
      allow(storage_proposal).to receive(:propose_and_store)
        .and_return(false)
      expect(subject.Import({})).to eq(false)
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
