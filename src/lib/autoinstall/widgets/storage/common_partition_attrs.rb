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
require "autoinstall/widgets/storage/size_selector"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Common partition section options
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
            HBox(
              HWeight(1, create_widget),
              HWeight(1, size_widget)
            )
          )
        end

        # @macro seeAbstractWidget
        def init
          create_widget.value = section.create
          size_widget.value = section.size
        end

        # Returns all widgets values
        #
        # @return [Hash<String,Object>]
        def values
          {
            "create" => create_widget.value,
            "size"   => size_widget.value
          }
        end

      private

        # @return [Presenters::Partition] presenter for the partition section
        attr_reader :section

        # Widget to set if the partition should be created or not
        #
        # @return [Create]
        def create_widget
          @create_widget ||= Create.new
        end

        # Widget to set the partition size
        #
        # @return [SizeSelector]
        def size_widget
          @size_widget ||= SizeSelector.new
        end
      end
    end
  end
end
