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
require "autoinstall/widgets/storage/partition_id"
require "autoinstall/widgets/storage/partition_type"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Not LVM partitions specific widgets
      #
      # It holds widgets managing specific attributes for a partition not related to a CT_LVM drive.
      #
      # @see PartitionGeneralTab
      class NotLvmPartitionAttrs < CWM::CustomWidget
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
            Left(
              HBox(
                HSquash(MinWidth(15, partition_id_widget)),
                HSpacing(2),
                HSquash(MinWidth(15, partition_type_widget))
              )
            )
          )
        end

        # @macro seeAbstractWidget
        def init
          partition_id_widget.value   = section.partition_id
          partition_type_widget.value = section.partition_type
        end

        # Returns the widgets values
        #
        # @return [Hash<String,Object>]
        def values
          {
            "partition_id"   => partition_id_widget.value,
            "partition_type" => partition_type_widget.value
          }
        end

      private

        # @return [Presenters::Partition] presenter for the partition section
        attr_reader :section

        # Widget for setting the partition id
        def partition_id_widget
          @partition_id_widget ||= PartitionId.new
        end

        # Widget for setting the partition type
        def partition_type_widget
          @partition_type_widget ||= PartitionType.new
        end
      end
    end
  end
end
