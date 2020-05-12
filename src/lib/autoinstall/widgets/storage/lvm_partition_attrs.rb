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
require "cwm/custom_widget"
require "autoinstall/widgets/storage/lv_name"
require "autoinstall/widgets/storage/pool"
require "autoinstall/widgets/storage/used_pool"

module Y2Autoinstallation
  module Widgets
    module Storage
      # LVM partitions specific widgets
      #
      # This is a custom widget holding those that are specific for a partition of an CT_LVM drive
      class LvmPartitionAttrs < CWM::CustomWidget
        # Constructor
        #
        # @param section [Presenters::Partition] presenter for the partition section
        def initialize(section)
          textdomain "autoinst"
          super()
          @section = section
        end

        # @macro seeAbstractWidget
        def label
          ""
        end

        # @macro seeCustomWidget
        def contents
          VBox(
            HBox(
              HWeight(1, lv_name_widget),
              HWeight(2, Empty())
            ),
            HBox(
              HWeight(1, pool_widget),
              HWeight(1, used_pool_widget),
              HWeight(1, Empty())
            )
          )
        end

        # @macro seeAbstractWidget
        def init
          lv_name_widget.value   = section.lv_name
          pool_widget.value      = section.pool
          used_pool_widget.value = section.used_pool
        end

        # Returns the widgets values
        #
        # @return [Hash<String,Object>]
        def values
          {
            "lv_name"   => lv_name_widget.value,
            "pool"      => pool_widget.value,
            "used_pool" => used_pool_widget.value
          }
        end

      private

        # @return [Presenters::Partition] presenter for the partition section
        attr_reader :section

        # Widget for setting the LV name
        #
        # @return [LvName]
        def lv_name_widget
          @lv_name_widget ||= LvName.new
        end

        # Widget for setting if LV should be an LVM thin pool
        #
        # @return [Pool]
        def pool_widget
          @pool_widget ||= Pool.new
        end

        # Widget for setting the name of the LVM thin pool used as data store
        #
        # @return [UsedPool]
        def used_pool_widget
          @used_pool_widget ||= UsedPool.new
        end
      end
    end
  end
end
