#!/usr/bin/env rspec

require_relative "../test_helper"
require "autoinstall/storage_proposal"

describe Y2Autoinstallation::StorageProposal do
  subject(:storage_proposal) { described_class.new(profile) }

  let(:storage_manager) { double(Y2Storage::StorageManager) }
  let(:guided_proposal) { instance_double(Y2Storage::GuidedProposal, propose: nil, proposed?: true) }
  let(:autoinst_proposal) { instance_double(Y2Storage::AutoinstProposal, propose: nil, proposed?: true) }

  before do
    allow(Y2Storage::StorageManager).to receive(:instance)
      .and_return(storage_manager)
    allow(Y2Storage::GuidedProposal).to receive(:initial)
      .and_return(guided_proposal)
    allow(Y2Storage::AutoinstProposal).to receive(:new)
      .and_return(autoinst_proposal)
    allow(storage_manager).to receive(:proposal=)
  end

  describe "#initialize" do
    context "when no partitioning plan is given" do
      let(:profile) { nil }

      it "creates a guided proposal" do
        expect(Y2Storage::GuidedProposal).to receive(:initial)
        expect(storage_proposal.proposal).to be(guided_proposal)
      end
    end

    context "when profile contains an empty set of partitions" do
      let(:profile) { [] }

      it "creates a guided proposal" do
        expect(Y2Storage::GuidedProposal).to receive(:initial)
        expect(storage_proposal.proposal).to be(guided_proposal)
      end
    end

    context "when a partition plan is given" do
      let(:profile) { [{ "device" => "/dev/sda" }] }

      it "creates an autoinstall proposal" do
        expect(Y2Storage::AutoinstProposal).to receive(:new)
          .with(partitioning: profile).and_return(autoinst_proposal)
        expect(autoinst_proposal).to receive(:propose)
        expect(storage_proposal.proposal).to be(autoinst_proposal)
      end
    end
  end

  describe "#save" do
    let(:profile) { nil }

    it "sets the proposal on the StorageManager" do
      expect(storage_manager).to receive(:proposal=).with(guided_proposal)
      storage_proposal.save
    end
  end
end
