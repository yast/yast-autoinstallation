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
require "autoinstall/widgets/storage/btrfs_name"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Btrfs member attributes
      #
      # It groups those attributes that are specific for a partition being used as a Btrfs member.
      #
      # @see PartitionUsageTab
      class BtrfsMemberAttrs < CWM::CustomWidget
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
          Left(HSquash(MinWidth(15, btrfs_name_widget)))
        end

        # @macro seeAbstractWidget
        def init
          btrfs_name_widget.items = section.available_btrfs
          btrfs_name_widget.value = section.btrfs_name
        end

        # Returns the widgets values
        #
        # @return [Hash<String,Object>]
        def values
          { "btrfs_name" => btrfs_name_widget.value }
        end

      private

        # @return [Presenters::Partition] presenter for the partition section
        attr_reader :section

        # Widget for setting the Btrfs multi-device filesystem
        def btrfs_name_widget
          @btrfs_name_widget ||= BtrfsName.new
        end
      end
    end
  end
end
