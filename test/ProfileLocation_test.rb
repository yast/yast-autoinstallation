#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "ProfileLocation"

describe "Yast::ProfileLocation" do

  subject { Yast::ProfileLocation }

  describe "#Process" do

    before do
      Yast::AutoinstConfig.scheme = "relurl"
      Yast::AutoinstConfig.xml_tmpfile = "/tmp/123"
      Yast::AutoinstConfig.filepath = "autoinst.xml"
      allow(Yast::InstURL).to receive(:installInf2Url).and_return(
        "http://download.opensuse.org/distribution/leap/15.1/repo/oss/"
      )
    end
    
    context "when scheme is \"relurl\"" do
      it "downloads AutoYaST configuration file with absolute path" do
        expect(subject).to receive(:Get).with("http",
          "download.opensuse.org",
          "/distribution/leap/15.1/repo/oss/autoinst.xml",
          "/tmp/123")
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
  end
end
