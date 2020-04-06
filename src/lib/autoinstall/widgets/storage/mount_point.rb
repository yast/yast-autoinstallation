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

require "yast"
require "cwm/common_widgets"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Widget to select the mount point for a file system

      # Constructor
      #
      # @param initial [String,nil] Initial value
      class MountPoint < CWM::ComboBox
        def initialize(initial: nil)
          @initial = initial
          super()
        end

        def opt
          [:editable, :hstretch]
        end

        def init
          self.value = @initial
        end

        ITEMS = [
          "/",
          "/boot",
          "/srv",
          "/tmp",
          "/usr/local",
          "swap"
        ].freeze
        private_constant :ITEMS

        def items
          return @items if @items
          known_items = ITEMS.dup
          known_items.unshift(@initial) if @initial && !ITEMS.include?(@initial)
          @items = known_items.map { |i| [i, i] }
        end

        def label
          _("Mount point")
        end

      private

        # @return [String,nil] Initial value
        attr_reader :initial
      end
    end
  end
end
