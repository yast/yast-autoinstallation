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

    context "when storage settings are specified" do
      let(:profile) do
        { "storage" => { "proposal_lvm" => true } }
      end

      it "overrides control file values" do
        expect(Yast::ProductFeatures).to receive(:SetOverlay)
          .with("partitioning" => profile["storage"])
        subject.Import(profile)
      end
    end

    context "when no partitioning plan is given" do
      let(:profile) do
        { "storage" => { "proposal_lvm" => true } }
      end

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
      let(:profile) do
        { "partitions" => [] }
      end

      it "sets a proposal" do
        expect(storage_manager).to receive(:proposal=).with(proposal)
        subject.Import(profile)
      end
    end

    context "when a partition plan is given" do
      let(:profile) { { "partitioning" => [{"device" => "/dev/sda"}] } }

      it "does not build a proposal" do
        expect(Y2Storage::Proposal).to_not receive(:new)
        subject.Import(profile)
      end

      it "returns false" do
        expect(subject.Import(profile)).to eq(false)
      end
    end
  end
end
