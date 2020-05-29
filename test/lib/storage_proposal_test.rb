#!/usr/bin/env rspec

require_relative "../test_helper"
require "autoinstall/storage_proposal"
require "y2storage/autoinst_issues"

describe Y2Autoinstallation::StorageProposal do
  subject(:storage_proposal) { described_class.new(profile, proposal_settings) }

  let(:storage_manager) { double(Y2Storage::StorageManager) }
  let(:devicegraph) { instance_double(Y2Storage::Devicegraph) }
  let(:guided_proposal) do
    instance_double(Y2Storage::GuidedProposal, propose: nil, proposed?: true, devices: devicegraph)
  end
  let(:autoinst_proposal) do
    instance_double(Y2Storage::AutoinstProposal, propose: nil, proposed?: true,
      devices: devicegraph)
  end
  let(:profile) { [{ "device" => "/dev/sda" }] }
  let(:proposal_settings) { Y2Storage::ProposalSettings.new }

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
          .with(partitioning: profile, proposal_settings: proposal_settings, issues_list: anything)
          .and_return(autoinst_proposal)
        expect(autoinst_proposal).to receive(:propose)
        expect(storage_proposal.proposal).to be(autoinst_proposal)
      end
    end

    context "when the proposal raises and exception" do
      before do
        allow(autoinst_proposal).to receive(:propose).and_raise(Y2Storage::Error)
      end

      it "registers an issue" do
        issues_list = storage_proposal.issues_list
        issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::Exception) }
        expect(issue).to_not be_nil
      end
    end

    context "when no proposal is possible" do
      let(:devicegraph) { nil }

      before do
        allow(guided_proposal).to receive(:devices).and_return(nil)
      end

      it "registers an issue" do
        issues_list = storage_proposal.issues_list
        issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::NoProposal) }
        expect(issue).to_not be_nil
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

  describe "#failed?" do
    let(:profile) { nil }

    before do
      allow(guided_proposal).to receive(:failed?).and_return(failed)
    end

    context "when the proposal has failed" do
      let(:failed) { true }

      it "returns true" do
        expect(storage_proposal.failed?).to eq(true)
      end
    end

    context "when the proposal is successful" do
      let(:failed) { false }

      it "returns false" do
        expect(storage_proposal.failed?).to eq(false)
      end
    end
  end

  describe "#valid?" do
    let(:profile) { [{ "device" => "/dev/sda" }] }
    let(:failed?) { false }
    let(:partition) { Y2Storage::Planned::Partition.new("/", nil) }
    let(:planned_devices) { [partition] }

    let(:proposal) do
      instance_double(
        Y2Storage::AutoinstProposal, planned_devices: planned_devices, failed?: failed?
      )
    end

    before do
      allow(proposal).to receive(:failed?).and_return(failed?)
      allow(storage_proposal).to receive(:proposal).and_return(proposal)
      allow(proposal).to receive(:planned_devices).and_return(planned_devices)
    end

    context "when the proposal did not fail" do
      it "returns true" do
        expect(storage_proposal).to be_valid
      end

      context "but an issue was detected" do
        before do
          storage_proposal.issues_list.add(Y2Storage::AutoinstIssues::MissingRoot)
        end

        it "returns false" do
          expect(storage_proposal).to_not be_valid
        end
      end
    end

    context "when the proposal failed" do
      let(:failed?) { true }

      it "returns false" do
        expect(storage_proposal).to_not be_valid
      end
    end
  end

  describe "#issues?" do
    let(:issues_list) { Y2Storage::AutoinstIssues::List.new }

    before do
      allow(storage_proposal).to receive(:issues_list).and_return(issues_list)
    end

    context "when no issues were found" do
      it "returns false" do
        expect(storage_proposal.issues?).to eq(false)
      end
    end

    context "when issues were found" do
      before { issues_list.add(Y2Storage::AutoinstIssues::MissingRoot) }

      it "returns true" do
        expect(storage_proposal.issues?).to eq(true)
      end
    end
  end
end
