#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "AutoinstPartition"

describe "Yast::AutoinstPartition" do
  subject { Yast::AutoinstPartition }

  describe "#parsePartition" do
    let(:filesystem) { :btrfs }
    let(:subvolumes) do
      [
        { "path" => ".snapshots/1" },
        { "path" => "var/lib/machines" }
      ]
    end

    let(:partition) do
      { "filesystem" => filesystem, "subvolumes" => subvolumes }
    end

    it "filters out snapper snapshots" do
      parsed = subject.parsePartition(partition)
      expect(parsed["subvolumes"]).to eq(
        [{ "path" => "var/lib/machines" }]
      )
    end

    context "when there are no Btrfs subvolumes" do
      let(:subvolumes) { [] }

      it "exports them as an empty array" do
        parsed = subject.parsePartition(partition)
        expect(parsed["subvolumes"]).to eq([])
      end

      context "and filesystem is not Btrfs" do
        let(:filesystem) { :ext4 }

        it "does not export the subvolumes list" do
          parsed = subject.parsePartition(partition)
          expect(parsed).to_not have_key("subvolumes")
        end
      end
    end

    context "when a partition_type is present" do
      let(:partition) do
        { "mount" => "/", "partition_type" => "primary" }
      end

      it "exports the partition type" do
        parsed = subject.parsePartition(partition)
        expect(parsed["partition_type"]).to eq("primary")
      end
    end

    context "when a partition_type is not present" do
      let(:partition) do
        { "mount" => "/" }
      end

      it "ignores the partition_type" do
        parsed = subject.parsePartition(partition)
        expect(parsed).to_not have_key("partition_type")
      end
    end
  end
end
