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

require "autoinstall/script"

module Y2Autoinstall
  # Scripts that are used when processing the <ask-list> section
  class AskScript < Y2Autoinstallation::ExecutedScript
    attr_reader :environment

    def self.type
      "ask-script"
    end

    def initialize(hash)
      super
      @environment = !!hash["environment"]
    end

    def to_hash
      super.merge("environment" => environment)
    end
  end
end
