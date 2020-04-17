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
require "y2storage"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Widget to select the chunk size for a RAID
      #
      # It corresponds to the `chunk_size` element within a `raid_options` section
      # of an AutoYaST profile.
      class ChunkSize < CWM::ComboBox
        # Constructor
        def initialize
          textdomain "autoinst"
          super()
        end

        # @macro seeAbstractWidget
        def label
          _("Chunk Size")
        end

        # TODO: the minimal size depends on the RAID level
        MIN_SIZE = Y2Storage::DiskSize.KiB(4)
        MAX_SIZE = Y2Storage::DiskSize.MiB(64)
        MULTIPLIER = 2

        # @macro seeComboBox
        def items
          return @items if @items

          sizes = []
          size = MIN_SIZE
          while size <= MAX_SIZE
            sizes << size
            size *= 2
          end
          @items = [["", _("Default")]] + sizes.map { |s| ["#{s.to_i}B", s.to_s] }
        end
      end
    end
  end
end
