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
require "autoinstall/widgets/storage/drive_page"
require "autoinstall/widgets/storage/btrfs_device"
require "autoinstall/widgets/storage/data_raid_level"
require "autoinstall/widgets/storage/metadata_raid_level"

module Y2Autoinstallation
  module Widgets
    module Storage
      # This page allows to edit a drive section representing a Btrfs device
      class BtrfsPage < DrivePage
        # @see DrivePage#initialize
        def initialize(*args)
          textdomain "autoinst"
          super
        end

        # @see DrivePage#widgets
        def widgets
          [
            HSquash(MinWidth(15, device_widget)),
            data_raid_level_widget,
            metadata_raid_level_widget
          ]
        end

        # @see DrivePage#init_widgets_values
        def init_widgets_values
          device_widget.value = section.device
          data_raid_level_widget.value = section.btrfs_options&.data_raid_level
          metadata_raid_level_widget.value = section.btrfs_options&.metadata_raid_level
        end

        # @see DrivePage#widgets_values
        def widgets_values
          {
            "device"        => device_widget.value,
            "btrfs_options" => {
              "data_raid_level"     => data_raid_level_widget.value,
              "metadata_raid_level" => metadata_raid_level_widget.value
            }
          }
        end

      private

        # Widget for setting the device
        def device_widget
          @device_widget ||= BtrfsDevice.new
        end

        # Widget for setting the data RAID level
        def data_raid_level_widget
          @data_raid_level_widget ||= DataRaidLevel.new
        end

        # Widget for setting the metadata RAID level
        def metadata_raid_level_widget
          @metadata_raid_level_widget ||= MetadataRaidLevel.new
        end
      end
    end
  end
end
