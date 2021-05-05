# Copyright (c) [2021] SUSE LLC
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

require_relative "../../test_helper"
require "autoinstall/script"
require "autoinstall/script_runner"

describe Y2Autoinstall::ScriptRunner do
  subject(:runner) { described_class.new }

  let(:script) { Y2Autoinstallation::PreScript.new(spec) }
  let(:spec) { { "filename" => "test.sh" } }

  describe "#run" do
    before do
      allow(Yast::SCR).to receive(:Read)
        .with(Yast::Path.new(".target.string"), script.log_path)
        .and_return("logs content")
      allow(script).to receive(:execute).and_return(true)
    end

    it "executes the script" do
      expect(script).to receive(:execute).and_return(true)
      runner.run(script)
    end

    context "when a notification is defined" do
      let(:spec) do
        { "notification" => "A script is running..." }
      end

      it "displays the notification" do
        expect(Yast::Popup).to receive(:ShowFeedback)
          .with("", "A script is running...")
        runner.run(script)
      end
    end

    context "when a notification is not defined" do
      it "does not display the notification" do
        expect(Yast::Popup).to_not receive(:ShowFeedback)
        runner.run(script)
      end
    end

    context "when feedback is enabled but the type is not set" do
      let(:spec) { { "feedback" => true } }

      it "displays the logs in a pop-up" do
        expect(Yast::Popup).to receive(:LongText)
        runner.run(script)
      end
    end

    context "when feedback is set to 'message'" do
      let(:spec) do
        { "feedback" => true, "feedback_type" => "message" }
      end

      it "displays the logs as a regular message" do
        expect(Yast::Report).to receive(:Message).with("logs content")
        runner.run(script)
      end
    end

    context "when feedback is set to 'warning'" do
      let(:spec) do
        { "feedback" => true, "feedback_type" => "warning" }
      end

      it "displays the logs as a warning" do
        expect(Yast::Report).to receive(:Warning).with("logs content")
        runner.run(script)
      end
    end

    context "when feedback is set to 'error'" do
      let(:spec) do
        { "feedback" => true, "feedback_type" => "error" }
      end

      it "displays the logs as a error" do
        expect(Yast::Report).to receive(:Error).with("logs content")
        runner.run(script)
      end
    end

    context "when the script failed" do
      before do
        allow(script).to receive(:execute).and_return(false)
      end

      it "reports the error" do
        expect(Yast::Report).to receive(:Warning)
          .with(/User script/, any_args)
        runner.run(script)
      end
    end
  end
end
