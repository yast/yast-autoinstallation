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
      # Determines the partition id
      class PartitionId < CWM::ComboBox
        # Constructor
        def initialize
          textdomain "autoinst"
          super
        end

        # @macro seeAbstractWidget
        def label
          _("Partition Id")
        end

        # @macro seeComboBox
        def items
          @items ||= [
            ["", ""],
            ["130", "130"], # Swap
            ["131", "131"], # Linux
            ["142", "142"], # LVM
            ["253", "253"], # MD RAID
            ["259", "259"]  # EFI Partition
          ]
        end

        # Returns partition id
        #
        # @return [String, Integer]
        def value
          partition_id = super

          partition_id.to_s.empty? ? partition_id : partition_id.to_i
        end

        # @macro seeComboBox
        def value=(id)
          super(id.to_s)
        end

        # @macro seeAbstractWidget
        def opt
          [:editable]
        end
      end
    end
  end
end
