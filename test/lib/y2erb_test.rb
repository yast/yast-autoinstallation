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

require "tempfile"
require "autoinstall/y2erb"

describe Y2Autoinstallation::Y2ERB do
  describe ".render" do
    it "returns string with rendered template" do
      # mock just for optimization
      allow(Yast::SCR).to receive(:Read).and_return({})
      file = Tempfile.new("test")
      path = file.path
      file.write("<test><%= hardware.inspect %></test>")
      file.close
      result = described_class.render(path)
      file.unlink

      expect(result).to match(/<test>{.*}<\/test>/)
    end
  end
end

