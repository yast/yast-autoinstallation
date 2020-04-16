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
      # Widget to select the MD Level
      #
      # It corresponds to the `raid_level` element within the `raid_options`
      # of an AutoYaST profile.
      class MdLevel < CWM::ComboBox
        # Constructor
        def initialize
          textdomain "autoinst"
          super()
        end

        # @macro seeAbstractWidget
        def label
          _("RAID Level")
        end

        # We are only interested in these levels.
        # @see https://github.com/openSUSE/libstorage-ng/blob/ffdd9abc800f8db14523979d5e8f2a237e97aeb6/storage/Devices/Md.h#L41-L44
        ITEMS = [
          Y2Storage::MdLevel::RAID0,
          Y2Storage::MdLevel::RAID1,
          Y2Storage::MdLevel::RAID4,
          Y2Storage::MdLevel::RAID5,
          Y2Storage::MdLevel::RAID6,
          Y2Storage::MdLevel::RAID10
        ].freeze
        private_constant :ITEMS

        # @macro seeComboBox
        def items
          ITEMS.map { |i| [i.to_s, i.to_human_string] }
        end
      end
    end
  end
end
