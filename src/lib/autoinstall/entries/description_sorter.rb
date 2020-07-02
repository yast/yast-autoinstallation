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

require "tsort"

module Y2Autoinstallation
  module Entries
    # Worker class for sorting description according their dependencies
    class DescriptionSorter
      def initialize(descriptions)
        @descriptions = descriptions
        @descriptions_map = Hash[descriptions.map { |d| [d.module_name, d] }]
      end

      # @return [Array<Description>] sorted module names. It should be written
      #   from first to the last.
      def sort
        each_node = ->(&b) { @descriptions_map.each_key(&b) }
        each_child = ->(n, &b) { @descriptions_map[n].required_modules.each(&b) }

        TSort.tsort(each_node, each_child).map { |mn| @descriptions_map[mn] }
      end
    end
  end
end
