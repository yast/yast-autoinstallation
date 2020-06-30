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

require "singleton"
require "autoinstallation/entries/description"

Yast.import "Desktop"

module Y2Autoinstallation
  module Entries
    # Represents registry holding descriptions and groups
    class Registry
      include Singleton

      def read
        Yast::Desktop.AgentPath = path(".autoyast2.desktop")
        Yast::Desktop.Read(Description::USED_VALUES)
        @descriptions = Yast::Desktop.Modules.map { |_, v| Description.new(v) }
        @groups = Yast::Desktop.Groups

        @read = true
      end

      def descriptions
        read unless @read

        @descriptions
      end

      def groups
        read unless @read

        @groups
      end

      # returns description for given alias or nil if argument is not alias
      # @return [Description, nil]
      def description_for_alias(alias_)
        descriptions.find { |d| d.aliases.include?(alias_) }
      end
    end
  end
end
