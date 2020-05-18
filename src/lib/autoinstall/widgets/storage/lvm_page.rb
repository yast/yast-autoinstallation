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
require "autoinstall/widgets/storage/drive_page"
require "autoinstall/widgets/storage/vg_device"
require "autoinstall/widgets/storage/vg_extent_size"
require "autoinstall/widgets/storage/md_level"
require "autoinstall/widgets/storage/chunk_size"
require "autoinstall/widgets/storage/parity_algorithm"

module Y2Autoinstallation
  module Widgets
    module Storage
      # This page allows to edit a `drive` section representing an LVM
      class LvmPage < DrivePage
        # @see DrivePage#initialize
        def initialize(*args)
          textdomain "autoinst"
          super
        end

        # @macro seeCustomWidget
        def contents
          VBox(
            Left(Heading(_("LVM"))),
            Left(vg_device_widget),
            Left(vg_pesize_widget),
            VStretch()
          )
        end

        # @macro seeAbstractWidget
        def init
          vg_device_widget.value = drive.device
          vg_pesize_widget.value = drive.pesize
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
