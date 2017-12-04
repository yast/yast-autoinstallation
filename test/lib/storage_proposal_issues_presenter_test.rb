#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../test_helper"
require "y2storage"
require "y2storage/autoinst_issues"
require "y2storage/autoinst_profile"
require "autoinstall/storage_proposal_issues_presenter"

describe Y2Autoinstallation::StorageProposalIssuesPresenter do
  subject(:presenter) { described_class.new(list) }
  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(partitioning_array)
  end

  let(:partitioning_array) do
    [
      {
        "device" => "/dev/sda", "use" => "all",
        "partitions" => [
          { "mount" => "/" },
          { "mount" => "/home", "raid_options" => { "raid_type" => "unknown" } }
        ]
      }
    ]
  end

  let(:raid_options_section) do
    partitioning.drives.first.partitions.last.raid_options
  end

  let(:part_section) do
    partitioning.drives.first.partitions.first
  end

  let(:list) { Y2Storage::AutoinstIssues::List.new }

  describe "#to_html" do
    context "when a fatal issue was found" do
      before do
        list.add(:missing_root)
      end

      it "includes issues messages" do
        issue = list.first
        expect(presenter.to_html.to_s).to include "<li>#{issue.message}</li>"
      end

      it "includes an introduction to fatal issues list" do
        expect(presenter.to_html.to_s).to include "<p>Important issues"
      end
    end

    context "when a non fatal issue was found" do
      before do
        list.add(:invalid_value, raid_options_section, :raid_type)
      end

      it "includes issues messages" do
        issue = list.first
        expect(presenter.to_html.to_s).to include "<li>#{issue.message}</li>"
      end

      it "includes an introduction to non fatal issues list" do
        expect(presenter.to_html.to_s).to include "<p>Minor issues"
      end

      it "includes the location information" do
        expect(presenter.to_html).to include "<li>drives[1] > partitions[2] > raid_options:<ul>"
      end
    end

    context "when a non located issue was found" do
      before do
        list.add(:missing_root)
      end

      it "includes issues messages" do
        issue = list.first
        expect(presenter.to_html.to_s).to include "<li>#{issue.message}</li>"
      end
    end
  end

  describe "#to_plain" do
    context "when a fatal issue was found" do
      before do
        list.add(:missing_root)
      end

      it "includes issues messages" do
        issue = list.first
        expect(presenter.to_plain.to_s).to include "* #{issue.message}"
      end

      it "includes an introduction to fatal issues list" do
        expect(presenter.to_plain.to_s).to include "Important issues"
      end
    end

    context "when a non fatal issue was found" do
      before do
        list.add(:invalid_value, raid_options_section, :raid_type)
      end

      it "includes issues messages" do
        issue = list.first
        expect(presenter.to_plain.to_s).to include "* #{issue.message}"
      end

      it "includes an introduction to non fatal issues list" do
        expect(presenter.to_plain.to_s).to include "Minor issues"
      end

      it "includes the location information" do
        expect(presenter.to_plain).to include "* drives[1] > partitions[2] > raid_options:"
      end
    end

    context "when a non located issue was found" do
      before do
        list.add(:missing_root)
      end

      it "includes issues messages" do
        issue = list.first
        expect(presenter.to_plain.to_s).to include "* #{issue.message}"
      end
    end
  end
end
