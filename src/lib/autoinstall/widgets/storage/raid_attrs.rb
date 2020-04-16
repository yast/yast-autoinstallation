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
require "autoinstall/widgets/storage/raid_name"

module Y2Autoinstallation
  module Widgets
    module Storage
      # File system specific widgets
      #
      # This is a custom widget that groups those that are RAID specific.
      class RaidAttrs < CWM::CustomWidget
        # Constructor
        #
        # @param controller [Y2Autoinstallation::StorageController] UI controller
        # @param section [Y2Storage::AutoinstProfile::PartitionSection] Partition section
        #   of the profile
        def initialize(controller, section)
          textdomain "autoinst"
          super()
          @controller = controller
          @section = section
        end

        # @macro seeAbstractWidget
        def label
          ""
        end

        # @macro seeCustomWidget
        def contents
          VBox(
            Left(raid_name_widget)
          )
        end

        # @macro seeAbstractWidget
        def init
          raid_name_widget.value = section.raid_name
        end

        # Returns the widgets values
        #
        # @return [Hash<String,Object>]
        def values
          { "raid_name" => raid_name_widget.value }
        end

      private

        # @return [Y2Autoinstallation::StorageController]
        attr_reader :controller

        # @return [Y2Storage::AutoinstProfile::PartitionSection]
        attr_reader :section

        # RAID name widget
        #
        # @return [RaidName]
        def raid_name_widget
          @raid_name_widget ||= RaidName.new
        end
      end
    end
  end
end
