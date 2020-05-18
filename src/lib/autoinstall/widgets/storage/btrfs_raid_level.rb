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
      # Widget to select a Btrfs RAID level
      class BtrfsRaidLevel < CWM::ComboBox
        # Constructor
        def initialize
          textdomain "autoinst"
          super()
        end

        # @macro seeAbstractWidget
        def label
          ""
        end

        # We are only interested in these levels.
        # @see https://github.com/yast/yast-storage-ng/blob/317eeb49d90d896eed95d9a0cf0bd9981e6430df/src/lib/y2partitioner/actions/controllers/btrfs_devices.rb
        BTRFS_RAID_LEVELS = [
          Y2Storage::BtrfsRaidLevel::DEFAULT,
          Y2Storage::BtrfsRaidLevel::SINGLE,
          Y2Storage::BtrfsRaidLevel::DUP,
          Y2Storage::BtrfsRaidLevel::RAID0,
          Y2Storage::BtrfsRaidLevel::RAID1,
          Y2Storage::BtrfsRaidLevel::RAID10
        ].freeze
        private_constant :BTRFS_RAID_LEVELS

        # @macro seeComboBox
        def items
          BTRFS_RAID_LEVELS.map { |i| [i.to_sym, i.to_human_string] }
        end
      end
    end
  end
end
