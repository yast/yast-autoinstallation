#!/usr/bin/env rspec

# Copyright (c) [2019-2021] SUSE LLC
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

require_relative "test_helper"

Yast.import "ProfileLocation"

describe "Yast::ProfileLocation" do

  subject { Yast::ProfileLocation }

  describe "#Process" do
    before do
      Yast::AutoinstConfig.scheme = "relurl"
      Yast::AutoinstConfig.xml_tmpfile = "/tmp/123"
      Yast::AutoinstConfig.filepath = filepath
      allow(Yast::InstURL).to receive(:installInf2Url).and_return(
        "http://download.opensuse.org/distribution/leap/15.1/repo/oss/"
      )
      allow(Yast::SCR).to receive(:Read).and_return("test")
      allow(Yast::Report).to receive(:Error) # test is already quite weak and some errors are shown
    end

    let(:filepath) { "autoinst.xml" }

    context "when scheme is \"relurl\"" do
      it "downloads AutoYaST configuration file with absolute path" do
        expect(subject).to receive(:Get).with("http",
          "download.opensuse.org",
          "/distribution/leap/15.1/repo/oss/autoinst.xml",
          "/tmp/123").and_return(false)
        # ^^^ Intentionally kill Process after get as rest of method is not tested and has too much
        # side effects

        subject.Process
      end
    end

    context "when scheme is corrupted" do
      before do
        allow(subject).to receive(:Get).with("http",
          "download.opensuse.org",
          "/distribution/leap/15.1/repo/oss/autoinst.xml",
          "/tmp/123").and_return("error_string").and_return(true)
        allow(Yast::SCR).to receive(:Read).with(Yast.path(".target.string"),
          Yast::AutoinstConfig.xml_tmpfile).and_return("error_string")
      end

      it "reports an error" do
        expect_any_instance_of(String).to receive(:valid_encoding?).and_return(false)
        expect(Yast::Report).to receive(:Error).with(/has no valid encoding or is corrupted/)
        subject.Process
      end
    end

    context "when the profile does not exist" do
      before do
        allow(subject).to receive(:Get).and_return(false)
      end

      it "reports an error" do
        expect(Yast::Report).to receive(:Error)
        expect(subject.Process).to eq(false)
      end

      context "and fetch errors are disabled" do
        around do |example|
          ENV["YAST_SKIP_PROFILE_FETCH_ERROR"] = "1"
          example.run
          ENV.delete("YAST_SKIP_PROFILE_FETCH_ERROR")
        end

        it "does not report an error" do
          expect(Yast::Report).to_not receive(:Error)
          expect(subject.Process).to eq(false)
        end
      end
    end

    context "when the profile is an erb file" do
      let(:filepath) { "autoinst.erb" }

      before do
        allow(Yast2::Popup).to receive(:show)

        allow(subject).to receive(:Get).and_return("test")

        allow(Yast::GPG).to receive(:encrypted_symmetric?).and_return(false)
      end

      context "and there is no error rendering the erb profile" do
        before do
          allow(Y2Autoinstallation::Y2ERB).to receive(:render)
            .with(Yast::AutoinstConfig.xml_tmpfile).and_return("rendered content")

          allow(Y2Autoinstallation::XmlChecks.instance).to receive(:valid_profile?).and_return(true)

          allow(Yast::SCR).to receive(:Write)
        end

        it "does not show rendering errors" do
          expect(Yast2::Popup).to_not receive(:show)

          subject.Process
        end
      end

      context "and there is some error rendering the erb profile" do
        before do
          allow(Y2Autoinstallation::Y2ERB).to receive(:render)
            .with(Yast::AutoinstConfig.xml_tmpfile).and_raise StandardError
        end

        it "shows a rendering error" do
          expect(Yast2::Popup).to receive(:show).with(/error while rendering/, anything)

          subject.Process
        end

        it "returns false" do
          expect(subject.Process).to eq(false)
        end
      end
    end
  end
end
