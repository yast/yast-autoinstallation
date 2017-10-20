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
require "y2storage/autoinst_issues"
require "autoinstall/storage_proposal_issues_presenter"

describe Y2Autoinstallation::StorageProposalIssuesPresenter do
  subject(:presenter) { described_class.new(list) }

  let(:list) { Y2Storage::AutoinstIssues::List.new }

  describe "#to_html" do
    context "when some fatal issue was found" do
      before do
        list.add(:missing_root)
      end

      it "includes issues messages" do
        issue = list.to_a.first
        expect(presenter.to_html.to_s).to include "<li>#{issue.message}</li>"
      end

      it "includes an introduction to fatal issues list" do
        expect(presenter.to_html.to_s).to include "<p>Some important problems"
      end
    end

    context "when some non fatal issue was found" do
      before do
        list.add(:invalid_value, "/", :size, "auto")
      end

      it "includes issues messages" do
        issue = list.to_a.first
        expect(presenter.to_html.to_s).to include "<li>#{issue.message}</li>"
      end

      it "includes an introduction to fatal issues list" do
        expect(presenter.to_html.to_s).to include "<p>Some minor problems"
      end
    end
  end

  describe "#to_plain" do
    context "when some fatal issue was found" do
      before do
        list.add(:missing_root)
      end

      it "includes issues messages" do
        issue = list.to_a.first
        expect(presenter.to_plain.to_s).to include "* #{issue.message}\n"
      end

      it "includes an introduction to fatal issues list" do
        expect(presenter.to_plain.to_s).to include "Some important problems"
      end
    end

    context "when some non fatal issue was found" do
      before do
        list.add(:invalid_value, "/", :size, "auto")
      end

      it "includes issues messages" do
        issue = list.to_a.first
        expect(presenter.to_plain.to_s).to include "* #{issue.message}\n"
      end

      it "includes an introduction to fatal issues list" do
        expect(presenter.to_plain.to_s).to include "Some minor problems"
      end
    end
  end
end
