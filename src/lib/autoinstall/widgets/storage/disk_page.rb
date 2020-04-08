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
require "cwm/page"
require "autoinstall/widgets/storage/add_children_button"
require "autoinstall/widgets/storage/disk_device"
require "autoinstall/widgets/storage/init_drive"
require "autoinstall/widgets/storage/disk_usage"
require "autoinstall/widgets/storage/partition_table"

module Y2Autoinstallation
  module Widgets
    module Storage
      # This page allows to edit usage information for a disk
      class DiskPage < ::CWM::Page
        # Constructor
        #
        # @param controller [Y2Autoinstallation::StorageController] UI controller
        # @param section [Y2Storage::AutoinstProfile::DriveSection] Drive section corresponding
        #   to a disk
        def initialize(controller, section)
          textdomain "autoinst"
          @controller = controller
          @section = section
          super()
          self.widget_id = "disk_page:#{section.object_id}"
          self.handle_all_events = true
        end

        # @macro seeAbstractWidget
        def label
          if section.device && !section.device.empty?
            format(_("Disk %{device}"), device: section.device)
          else
            format(_("Disk"))
          end
        end

        # @macro seeCustomWidget
        def contents
          VBox(
            Left(Heading(_("Disk"))),
            VBox(
              Left(disk_device_widget),
              Left(init_drive_widget),
              Left(disk_usage_widget),
              Left(partition_table_widget),
              VStretch()
            ),
            HBox(
              HStretch(),
              AddChildrenButton.new(controller, section)
            )
          )
        end

        # @macro seeAbstractWidget
        def init
          disk_device_widget.value = section.device
          init_drive_widget.value = !!section.initialize_attr
          disk_usage_widget.value = section.use
          partition_table_widget.value = section.disklabel
          set_disk_usage_status
        end

        # @macro seeAbstractWidget
        def store
          section.device = disk_device_widget.value
          section.initialize_attr = init_drive_widget.value
          section.use = disk_usage_widget.value
          section.disklabel = partition_table_widget.value
        end

        # @macro seeAbstractWidget
        def handle(event)
          set_disk_usage_status if event["ID"] == init_drive_widget.widget_id
          nil
        end

      private

        # @return [Y2Autoinstallation::StorageController]
        attr_reader :controller

        # @return [Y2Storage::AutoinstProfile::DriveSection]
        attr_reader :section

        # Disk device selector
        #
        # @return [DiskDevice]
        def disk_device_widget
          @disk_device_widget ||= DiskDevice.new
        end

        # Disk usage selector
        #
        # @return [DiskUsage]
        def disk_usage_widget
          @disk_usage_widget ||= DiskUsage.new
        end

        # Partition table selector
        #
        # @return [PartitionTable]
        def partition_table_widget
          @partition_table_widget ||= PartitionTable.new
        end

        # Initialize drive widget
        #
        # @param [InitDrive]
        def init_drive_widget
          @init_drive_widget ||= InitDrive.new
        end

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
