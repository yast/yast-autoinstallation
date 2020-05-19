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
require "autoinstall/widgets/storage/disk_device"
require "autoinstall/widgets/storage/init_drive"
require "autoinstall/widgets/storage/disk_usage"
require "autoinstall/widgets/storage/partition_table"

module Y2Autoinstallation
  module Widgets
    module Storage
      # This page allows to edit usage information for a disk
      class DiskPage < DrivePage
        # @see DrivePage#initialize
        def initialize(*args)
          textdomain "autoinst"
          super
        end

        # @see DrivePage#widgets
        def widgets
          [
            HSquash(MinWidth(15, disk_device_widget)),
            init_drive_widget,
            disk_usage_widget,
            partition_table_widget
          ]
        end

        # @see DrivePage#init_widgets_values
        def init_widgets_values
          disk_device_widget.value = drive.device
          init_drive_widget.value = !!drive.initialize_attr
          disk_usage_widget.value = drive.use
          partition_table_widget.value = drive.disklabel
          set_disk_usage_status
        end

        # @see DrivePage#widgets_values
        def widgets_values
          {
            "device"          => disk_device_widget.value,
            "initialize_attr" => init_drive_widget.value,
            "use"             => disk_usage_widget.value,
            "disklabel"       => partition_table_widget.value
          }
        end

        # @macro seeAbstractWidget
        def handle(event)
          set_disk_usage_status if event["ID"] == init_drive_widget.widget_id
          nil
        end

      private

        # Widget for setting the device name
        def disk_device_widget
          @disk_device_widget ||= DiskDevice.new
        end

        # Widget for setting the disk use
        def disk_usage_widget
          @disk_usage_widget ||= DiskUsage.new
        end

        # Widget for setting the disk partition table
        def partition_table_widget
          @partition_table_widget ||= PartitionTable.new
        end

        # Widget for settings if disk should be initialize
        def init_drive_widget
          @init_drive_widget ||= InitDrive.new
        end

        # Update the disk use status according to the value of #init_drive_widget
        def set_disk_usage_status
          if init_drive_widget.value
            disk_usage_widget.disable
          else
            disk_usage_widget.enable
          end
        end
      end
    end
  end
end
