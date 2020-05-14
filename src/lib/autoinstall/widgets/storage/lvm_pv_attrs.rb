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
require "autoinstall/widgets/storage/lvm_group"

module Y2Autoinstallation
  module Widgets
    module Storage
      # LVM Physical Volumne attributes widget
      #
      # This is a custom widget that groups those that are LVM specific.
      class LvmPvAttrs < CWM::CustomWidget
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
          Left(HSquash(MinWidth(15, lvm_group_widget)))
        end

        # @macro seeAbstractWidget
        def init
          lvm_group_widget.items = section.available_lvm_groups
          lvm_group_widget.value = section.lvm_group
        end

        # Returns the widgets values
        #
        # @return [Hash<String,Object>]
        def values
          { "lvm_group" => lvm_group_widget.value }
        end

      private

        # @return [Presenters::Partition] presenter for the partition section
        attr_reader :section

        # LVM Group widget
        #
        # @return [VgName]
        def lvm_group_widget
          @lvm_group_widget ||= LvmGroup.new
        end
      end
    end
  end
end
