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

require_relative "../../test_helper"
require "autoinstall/dialogs/question"
require "y2storage/autoinst_issues"

describe Y2Autoinstallation::Dialogs::Question do
  subject(:dialog) { described_class.new(content, timeout: timeout, buttons_set: buttons_set) }

  let(:timeout) { 0 }
  let(:content) { "some content" }
  let(:buttons_set) { :abort }

  before do
    allow(Yast::UI).to receive(:OpenDialog).and_return(true)
    allow(Yast::UI).to receive(:CloseDialog).and_return(true)
  end

  describe "#dialog_content" do
    it "displays the given content" do
      expect(dialog.dialog_content.to_s).to include(content)
    end

    context "when buttons_set is set to :abort" do
      let(:buttons_set) { :abort }

      it "only shows the 'Abort' button" do
        expect(dialog).to receive(:PushButton).with(Yast::Term.new(:id, :abort), anything, anything)
        dialog.dialog_content
      end

      context "and a timeout was given" do
        it "ignores the timeout" do
          expect(dialog).to receive(:PushButton).with(Yast::Term.new(:id, :abort), anything, anything)
          expect(dialog).to_not receive(:Id).with(:counter)
          allow(dialog).to receive(:Id).and_call_original
          dialog.dialog_content
        end
      end
    end

    context "when buttons_set is set to :question" do
      let(:buttons_set) { :question }

      it "shows the 'Continue' and 'Abort' buttons" do
        expect(dialog).to receive(:PushButton).with(Yast::Term.new(:id, :abort), anything, anything)
        expect(dialog).to receive(:PushButton).with(Yast::Term.new(:id, :ok), anything, anything)
        dialog.dialog_content
      end

      context "and a timeout was given" do
        let(:timeout) { 10 }

        it "shows the 'Stop' button" do
          expect(dialog).to receive(:PushButton).with(Yast::Term.new(:id, :stop), anything, anything)
          allow(dialog).to receive(:PushButton).and_call_original
          dialog.dialog_content
        end
      end
    end
  end

  describe "#run" do
    let(:timeout) { 10 }

    context "when no timeout was given" do
      let(:timeout) { 0 }

      it "does not use a timeout when asking for user input" do
        expect(Yast::UI).to receive(:UserInput).and_return(:ok)
        dialog.run
      end
    end

    context "when user pushes 'Abort'" do
      let(:input) { :abort }

      it "returns :abort" do
        allow(Yast::UI).to receive(:TimeoutUserInput).and_return(:abort)
        expect(dialog.run).to eq(:abort)
      end
    end

    context "when user pushes 'Continue'" do
      it "returns :ok" do
        allow(Yast::UI).to receive(:TimeoutUserInput).and_return(:ok)
        expect(dialog.run).to eq(:ok)
      end
    end

    context "when user pushes 'Stop'" do
      it "stops the countdown" do
        allow(Yast::UI).to receive(:TimeoutUserInput).and_return(:stop)
        allow(Yast::UI).to receive(:UserInput).and_return(:ok)
        expect(Yast::UI).to receive(:ChangeWidget)
          .with(Id(:stop), :Enabled, false)
        dialog.run
      end
    end

    context "when user input times-out" do
      let(:timeout) { 1 }

      it "returns :ok" do
        allow(Yast::UI).to receive(:TimeoutUserInput).and_return(:timeout)
        expect(dialog.run).to eq(:ok)
      end
    end
  end
end
