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
require "autoinstall/widgets/storage/bcache_device"
require "autoinstall/widgets/storage/cache_mode"

module Y2Autoinstallation
  module Widgets
    module Storage
      # This page allows to edit a drive section representing a bcache device
      class BcachePage < DrivePage
        # @see DrivePage#initialize
        def initialize(*args)
          textdomain "autoinst"
          super
        end

        # @see DrivePage#widgets
        def widgets
          [
            HSquash(MinWidth(15, device_widget)),
            cache_mode_widget
          ]
        end

        # @see DrivePage#init_widget_values
        def init_widgets_values
          device_widget.value = section.device
          cache_mode_widget.value = section.bcache_options&.cache_mode
        end

        # @see DrivePage#widgets_values
        def widgets_values
          {
            "device"         => device_widget.value,
            "bcache_options" => {
              "cache_mode" => cache_mode_widget.value
            }
          }
        end

      private

        # Widget for setting the device
        def device_widget
          @device_widget ||= BcacheDevice.new
        end

        # Widget for setting the cache mode
        def cache_mode_widget
          @cache_mode_widget ||= CacheMode.new
        end
      end
    end
  end
end
