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
      # Widget for the LVM VG extent size
      class VgExtentSize < CWM::ComboBox
        SUGGESTED_SIZES = ["1 MiB", "2 MiB", "4 MiB", "8 MiB", "16 MiB", "32 MiB", "64 MiB"].freeze

        # Constructor
        def initalize
          textdomain "autoinst"
          super
        end

        def opt
          [:editable]
        end

        # @macro seeAbstractWidget
        def label
          # TRANSLATORS: field to enter the extent size of a new volume group
          _("Physical Extent Size")
        end

        # Returns selected size
        #
        # @return [String] a human readable disk size
        def value
          Y2Storage::DiskSize.from_s(super).to_s
        end

        # Updates the value with a human readable version of given size
        #
        # @param size [#to_s]
        def value=(size)
          return if size.nil?

          super(Y2Storage::DiskSize.from_s(size.to_s).to_s)
        end

        # @macro seeAbstractWidget
        def help
          # TRANSLATORS: help text
          _("<p><b>Physical Extent Size:</b> " \
            "The smallest size unit used for volumes. " \
            "This cannot be changed after creating the volume group. " \
            "You can resize a logical volume only in multiples of this size." \
            "</p>")
        end

        # @macro seeAbstractWidget
        def items
          SUGGESTED_SIZES.map { |mp| [mp, mp] }
        end
      end
    end
  end
end
