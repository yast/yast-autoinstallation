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
require "autoinstall/widgets/storage/create"
require "autoinstall/widgets/storage/format"
require "autoinstall/widgets/storage/resize"
require "autoinstall/widgets/storage/size"
require "autoinstall/widgets/storage/partition_nr"
require "autoinstall/widgets/storage/uuid"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Common partition section options
      #
      # It holds widgets managing common partition attributes, no matter the parent drive section.
      #
      # @see PartitionGeneralTab
      class CommonPartitionAttrs < CWM::CustomWidget
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
                create_widget,
                HSpacing(2),
                format_widget
              )
            ),
            VSpacing(0.5),
            Left(
              HBox(
                resize_widget,
                HSpacing(2),
                HSquash(MinWidth(15, size_widget))
              )
            ),
            VSpacing(0.5),
            Left(
              HBox(
                HSquash(MinWidth(15, partition_nr_widget)),
                HSpacing(2),
                HSquash(MinWidth(15, uuid_widget))
              )
            )
          )
        end

        # @macro seeAbstractWidget
        def init
          create_widget.value       = section.create
          format_widget.value       = section.format
          resize_widget.value       = section.resize
          size_widget.value         = section.size
          partition_nr_widget.value = section.partition_nr
          uuid_widget.value         = section.uuid
        end

        # Returns all widgets values
        #
        # @return [Hash<String,Object>]
        def values
          {
            "create"       => create_widget.value,
            "format"       => format_widget.value,
            "resize"       => resize_widget.value,
            "size"         => size_widget.value,
            "partition_nr" => partition_nr_widget.value,
            "uuid"         => uuid_widget.value
          }
        end

      private

        # @return [Presenters::Partition] presenter for the partition section
        attr_reader :section

        # Widget for setting if partition should be created
        def create_widget
          @create_widget ||= Create.new
        end

        # Widget for setting if partition should be formatted
        def format_widget
          @format_widget ||= Format.new
        end

        # Widget for setting if partition should be resized
        def resize_widget
          @resize_widget ||= Resize.new
        end

        # Widget for setting the partition size
        def size_widget
          @size_widget ||= Size.new
        end

        # Widget for setting the partition_nr
        def partition_nr_widget
          @partition_nr_widget ||= PartitionNr.new
        end

        # Widget for setting the partition uuid
        def uuid_widget
          @uuid_widget ||= Uuid.new
        end
      end
    end
  end
end
