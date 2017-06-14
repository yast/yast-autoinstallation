#!/usr/bin/env rspec

require_relative "../test_helper"
require "autoinstall/storage_proposal"

describe Y2Autoinstallation::StorageProposal do
  subject(:storage_proposal) { described_class.new(profile) }

  describe "#propose" do
    let(:proposal_settings) { double("proposal_settings") }
    let(:guided_proposal) { instance_double(Y2Storage::GuidedProposal, propose: nil, proposed?: true) }
    let(:autoinst_proposal) { instance_double(Y2Storage::AutoinstProposal, propose: nil, proposed?: true) }
    let(:devicegraph) { instance_double(Y2Storage::Devicegraph) }
    let(:storage_manager) { double("storage_manager", y2storage_probed: devicegraph) }
    let(:disk_analyzer) { instance_double(Y2Storage::DiskAnalyzer) }

    before do
      allow(Y2Storage::StorageManager).to receive(:instance)
        .and_return(storage_manager)
      allow(Y2Storage::GuidedProposal).to receive(:new)
        .and_return(guided_proposal)
      allow(Y2Storage::AutoinstProposal).to receive(:new)
        .and_return(autoinst_proposal)
      allow(storage_manager).to receive(:proposal=)
    end

    context "when no partitioning plan is given" do
      let(:profile) { nil }

      it "sets a guided proposal" do
        expect(storage_manager).to receive(:proposal=).with(guided_proposal)
        storage_proposal.propose_and_store
      end

      it "returns true" do
        expect(subject.propose_and_store).to eq(true)
      end

      context "if proposal fails" do
        before do
          allow(guided_proposal).to receive(:propose).and_raise(Y2Storage::Error)
        end

        it "does not set the proposal" do
          expect(storage_manager).to_not receive(:proposal=)
          storage_proposal.propose_and_store
        end

        it "returns false" do
          expect(storage_manager).to_not receive(:proposal=)
          storage_proposal.propose_and_store
        end
      end
    end

    context "when profile contains an empty set of partitions" do
      let(:profile) { [] }

      it "sets a proposal" do
        expect(storage_manager).to receive(:proposal=).with(guided_proposal)
        storage_proposal.propose_and_store
      end
    end

    context "when a partition plan is given" do
      let(:profile) { [{ "device" => "/dev/sda" }] }

      before do
        allow(Y2Storage::AutoinstProposal).to receive(:new).and_return(autoinst_proposal)
        allow(Y2Storage::DiskAnalyzer).to receive(:new).with(devicegraph).and_return(disk_analyzer)
      end

      it "asks for a proposal" do
        expect(Y2Storage::AutoinstProposal).to receive(:new)
          .with(partitioning: profile, devicegraph: devicegraph, disk_analyzer: disk_analyzer)
          .and_return(autoinst_proposal)
        expect(autoinst_proposal).to receive(:propose)
        storage_proposal.propose_and_store
      end

      it "returns true" do
        expect(storage_proposal.propose_and_store).to eq(true)
      end
    end
  end
end
