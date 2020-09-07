#!/usr/bin/env rspec
# Copyright (c) [2020] SUSE LLC
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
require "autoinstall/decrypter"
require "tempfile"

describe Y2Autoinstallation::Decrypter do
  let(:file_content) do
    "-----BEGIN PGP MESSAGE-----

    jA0ECQMCcDEcLgINyN7u0sAmAVC1w1tmY2SohOmPd4ChbkpPtEzvPbVQ+0TdOnQM
    Jpf3i4cPHTF0hw624N+SfIvlyAxu3VG6Ck7FDtWieBQlcSYEvZ1eIZAlD4jZIE5R
    lp6JwzelfxbMvX9jmqhPpLSKYJBlbThce9Yr3MUfIrURleiD6YTCuse7YrbmmDfP
    ZZzVXqyl9IzENi09awxCOVHbrz5Fn7urWFB2onM5xuyT0C82EGTfpuiPrQDo2Gfw
    iEES4TGKcP0xRcXeXHaHg20ddHJvozM3RXphqfwhdJ2CylumgYnjZVkYZHM39Sdk
    drSOtqVQVLM=
    =xi/T
    -----END PGP MESSAGE-----"
  end

  let(:label) { "test" }

  describe "#decrypt" do
    before do
      allow(Yast::UI).to receive(:OpenDialog)
      allow(Yast::UI).to receive(:UserInput).and_return(:ok)
      allow(Yast::UI).to receive(:QueryWidget).and_return("test")
    end

    around do |t|
      file = Tempfile.open
      file.write file_content
      file.close

      @path = file.path

      t.call

      file.unlink
    end

    context "file contain gpg encrypted file" do
      it "asks for password" do
        expect(Yast::UI).to receive(:OpenDialog)

        described_class.decrypt(@path, label)
      end

      it "returns content if password was correct" do
        expect(described_class.decrypt(@path, label)).to match(/<zeroOrMore>/)
      end

      it "shows error popup if password is not correct" do
        expect(Yast::Popup).to receive(:Error)
        allow(Yast::UI).to receive(:QueryWidget).and_return("wrong", "test")

        described_class.decrypt(@path, label)
      end
    end

    context "file is not encrypted" do
      let(:file_content) { "test\n" }

      it "returns content of file" do
        expect(described_class.decrypt(@path, label)).to eq "test\n"
      end
    end
  end

  describe "#encrypted?" do
    it "returns true if passed content is gpg encrypted" do
      expect(described_class.encrypted?(file_content)).to eq true
    end

    it "returns false otherwise" do
      expect(described_class.encrypted?("test")).to eq false
      expect(described_class.encrypted?("")).to eq false
    end
  end
end
