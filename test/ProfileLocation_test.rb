#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "ProfileLocation"

describe "Yast::ProfileLocation" do

  subject { Yast::ProfileLocation }

  describe "#Process" do
 
    context "when scheme is \"relurl\"" do
      before do
        Yast::AutoinstConfig.scheme = "relurl"
        Yast::AutoinstConfig.xml_tmpfile = "/tmp/123"
        Yast::AutoinstConfig.filepath = "autoinst.xml"
        allow(Yast::InstURL).to receive(:installInf2Url).and_return(
          "http://download.opensuse.org/distribution/leap/15.1/repo/oss/")
      end

      it "downloads AutoYaST configuration file with absolute path" do
        expect(subject).to receive(:Get).with("http",
          "download.opensuse.org",
          "/distribution/leap/15.1/repo/oss/autoinst.xml",
          "/tmp/123")
        subject.Process
      end
    end
  end
end
