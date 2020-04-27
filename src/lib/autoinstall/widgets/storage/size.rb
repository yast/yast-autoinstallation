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
require "y2storage"
require "cwm/common_widgets"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Determines the size of a section
      class Size < CWM::ComboBox
        ITEMS = [
          "",
          "auto",
          "max"
        ].freeze
        private_constant :ITEMS

        # Constructor
        def initialize
          textdomain "autoinst"
          super
        end

        # @macro seeAbstractWidget
        def label
          _("Size")
        end

        # @macro seeComboBox
        def items
          @items ||= ITEMS.map { |i| [i, i] }
        end

        # Returns selected size
        #
        # @return [String] a human readable disk size
        def value
          formatted_size(super)
        end

        # @macro seeComboBox
        def value=(size)
          super(formatted_size(size))
        end

        # @macro seeAbstractWidget
        def opt
          [:editable]
        end

      private

        # Format given size, when possible
        #
        # @return [String] a human readable disk size or given value when cannot perform the format
        def formatted_size(size)
          Y2Storage::DiskSize.from_s(size.to_s).to_human_string
        rescue TypeError
          size
        end
      end
    end
  end
end
