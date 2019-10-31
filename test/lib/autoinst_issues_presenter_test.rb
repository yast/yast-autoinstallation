#!/usr/bin/env rspec
# Copyright (c) [2018] SUSE LLC
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
require "autoinstall/autoinst_issues"
require "autoinstall/autoinst_issues_presenter"

describe Y2Autoinstallation::AutoinstIssuesPresenter do
  subject(:presenter) { described_class.new(list) }

  let(:list) { Y2Autoinstallation::AutoinstIssues::List.new }

  describe "#to_html" do
    context "when a fatal issue was found" do
      before do
        list.add(:missing_value, "foo", "bar",
          "The installer is trying to evaluate bar.",
          :fatal)
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
        list.add(:invalid_value, "firewall", "interfaces", "eth0",
          "This interface has been defined for more than one zone.")
      end

      it "includes issues messages" do
        issue = list.first
        expect(presenter.to_html.to_s).to include "<li>#{issue.message}</li>"
      end

      it "includes an introduction to non fatal issues list" do
        expect(presenter.to_html.to_s).to include "<p>Minor issues"
      end
    end
  end

  describe "#to_plain" do
    context "when a fatal issue was found" do
      before do
        list.add(:missing_value, "foo", "bar",
          "The installer is trying to evaluate bar.",
          :fatal)
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
        list.add(:invalid_value, "firewall", "interfaces", "eth0",
          "This interface has been defined for more than one zone.")
      end

      it "includes issues messages" do
        issue = list.first
        expect(presenter.to_plain.to_s).to include "* #{issue.message}"
      end

      it "includes an introduction to non fatal issues list" do
        expect(presenter.to_plain.to_s).to include "Minor issues"
      end
    end
  end
end
