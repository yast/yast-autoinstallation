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
require "cwm/page"
require "autoinstall/widgets/storage/add_children_button"
require "autoinstall/widgets/storage/vg_device"
require "autoinstall/widgets/storage/vg_extent_size"
require "autoinstall/widgets/storage/md_level"
require "autoinstall/widgets/storage/chunk_size"
require "autoinstall/widgets/storage/parity_algorithm"

module Y2Autoinstallation
  module Widgets
    module Storage
      # This page allows to edit a `drive` section representing an LVM
      class LvmPage < ::CWM::Page
        # Constructor
        #
        # @param controller [Y2Autoinstallation::StorageController] UI controller
        # @param section [Y2Storage::AutoinstProfile::DriveSection] Drive section corresponding
        #   to a RAID
        def initialize(controller, section)
          textdomain "autoinst"
          @controller = controller
          @section = section
          super()
          self.widget_id = "raid_page:#{section.object_id}"
          self.handle_all_events = true
        end

        # @macro seeAbstractWidget
        def label
          format(_("Drive: LVM %{device}"), device: section.device)
        end

        # @macro seeCustomWidget
        def contents
          VBox(
            Left(Heading(_("LVM"))),
            VBox(
              Left(vg_device_widget),
              Left(vg_pesize_widget),
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
          vg_device_widget.items = controller.lvm_devices
          vg_device_widget.value = section.device
          vg_pesize_widget.value = section.pesize
        end

        # @macro seeAbstractWidget
        def store
          controller.update_drive(section, values)
        end

        # Returns the widgets values
        #
        # @return [Hash<String,Object>]
        def values
          {
            "device" => vg_device_widget.value,
            "pesize" => vg_pesize_widget.value
          }
        end

      private

        # @return [Y2Autoinstallation::StorageController]
        attr_reader :controller

        # @return [Y2Storage::AutoinstProfile::DriveSection]
        attr_reader :section

        # LVM VG name input field
        #
        # @return [VgName]
        def vg_device_widget
          @vg_device_widget ||= VgDevice.new
        end

        # LVM VG Physical Extent Size (pesize)
        #
        # @return [VgExtentSize]
        def vg_pesize_widget
          @vg_pesize_widget ||= VgExtentSize.new
        end
      end
    end
  end
end
