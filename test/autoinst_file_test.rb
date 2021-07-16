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

# !/usr/bin/env rspec

require_relative "test_helper"
require "tmpdir"

Yast.import "AutoinstFile"

describe Yast::AutoinstFile do
  subject { Yast::AutoinstFile }

  describe "#Write" do
    let(:scr_root_dir) { Dir.mktmpdir("YaST-") }

    before do
      allow(Yast::Installation).to receive(:destdir).and_return(scr_root_dir)
      allow(Yast::SCR).to receive(:Execute).and_call_original
      subject.Import(profile)
    end

    around do |example|
      change_scr_root(scr_root_dir, &example)
      FileUtils.remove_entry(scr_root_dir) if Dir.exist?(scr_root_dir)
    end

    context "when the file path ends with a slash" do
      let(:profile) do
        [{ "file_path" => "/etc/", "file_permissions" => "750", "file_owner" => "root" }]
      end

      it "considers the file to be a directory" do
        expect(Yast::SCR)
          .to receive(:Execute).with(Yast::Path.new(".target.bash"), "chmod 750 /etc/")
        expect(Yast::SCR)
          .to receive(:Execute).with(Yast::Path.new(".target.bash"), "chown root /etc/")

        subject.Write

        expect(Dir).to exist(File.join(scr_root_dir, "etc"))
      end
    end

    context "when file contents are given" do
      let(:profile) do
        [
          { "file_path" => "/etc/" },
          {
            "file_contents" => "hello!", "file_path" => "/etc/motd",
            "file_permissions" => "644", "file_owner" => "root"
          }
        ]
      end

      it "writes the contents to the destdir" do
        expect(Yast::SCR)
          .to receive(:Execute).with(Yast::Path.new(".target.bash"), "chmod 644 /etc/motd")
        expect(Yast::SCR)
          .to receive(:Execute).with(Yast::Path.new(".target.bash"), "chown root /etc/motd")

        subject.Write

        content = File.read(File.join(scr_root_dir, "etc", "motd"))
        expect(content).to eq("hello!")
      end
    end

    context "when a file location is given" do
      let(:profile) do
        [
          {
            "file_location" => "http://example.net/test", "file_path" => "/test.txt",
            "file_permissions" => "644", "file_owner" => "root"
          }
        ]
      end

      it "copies the file to the destdir" do
        expect(Yast::SCR)
          .to receive(:Execute).with(Yast::Path.new(".target.bash"), "chmod 644 /test.txt")
        expect(Yast::SCR)
          .to receive(:Execute).with(Yast::Path.new(".target.bash"), "chown root /test.txt")
        expect(subject)
          .to receive(:GetURL).with("http://example.net/test", File.join(scr_root_dir, "test.txt"))

        subject.Write
      end

    end
  end
end
