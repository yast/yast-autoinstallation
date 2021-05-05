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
require "autoinstall/ask_default_value_script"
require "tmpdir"

describe Y2Autoinstall::AskDefaultValueScript do
  subject(:script) do
    described_class.new(
      "source"   => "echo -n 'test'",
      "filename" => "test.sh"
    )
  end

  describe "#execute" do
    let(:tmp_dir) { Dir.mktmpdir }

    before do
      allow(script).to receive(:script_path)
        .and_return(File.join(tmp_dir, script.script_name))
    end

    after do
      FileUtils.remove_entry(tmp_dir) if Dir.exist?(tmp_dir)
    end

    it "returns the script output" do
      script.create_script_file
      expect(script.execute).to eq("test")
    end
  end
end
