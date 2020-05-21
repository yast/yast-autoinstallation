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
require "autoinstall/widgets/storage/pesize"
require "autoinstall/widgets/storage/keep_unknown_lv"

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

        # @see DrivePage#widgets
        def widgets
          [
            HSquash(MinWidth(15, vg_device_widget)),
            HSquash(MinWidth(15, pesize_widget)),
            keep_unknown_lv_widget
          ]
        end

        # @see DrivePage#init_widgets_values
        def init_widgets_values
          vg_device_widget.value       = drive.device
          pesize_widget.value          = drive.pesize
          keep_unknown_lv_widget.value = drive.keep_unknown_lv
        end

        # @see DrivePage#widgets_values
        def widgets_values
          {
            "device"          => vg_device_widget.value,
            "pesize"          => pesize_widget.value,
            "keep_unknown_lv" => keep_unknown_lv_widget.value
          }
        end

      private

        # Widget for setting the LVM VG name
        def vg_device_widget
          @vg_device_widget ||= VgDevice.new
        end

        # Widget for setting the LVM VG Physical Extent Size (pesize)
        def pesize_widget
          @pesize_widget ||= Pesize.new
        end

        # Widget for setting if an unknown LV must be kept
        def keep_unknown_lv_widget
          @keep_unknown_lv_widget ||= KeepUnknownLv.new
        end
      end
    end
  end
end
