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
require "cwm/page"
require "autoinstall/widgets/storage/add_children_button"
require "autoinstall/widgets/storage/raid_name"
# require "autoinstall/widgets/storage/raid_options"

module Y2Autoinstallation
  module Widgets
    module Storage
      # This page allows to edit a `drive` section representing a RAID device
      class RaidPage < ::CWM::Page
        # Constructor
        #
        # @param controller [Y2Autoinstallation::StorageController] UI controller
        # @param section [Y2Storage::AutoinstProfile::DriveSection] Drive section corresponding
        #   to a RAID
        def initialize(controller, section)
          textdomain "autoinst"
          @controller = controller
          @section = section
          super()
          self.widget_id = "raid_page:#{section.object_id}"
          self.handle_all_events = true
        end

        # @macro seeAbstractWidget
        def label
          format(_("RAID %{device}"), device: section.device)
        end

        # @macro seeCustomWidget
        def contents
          VBox(
            Left(Heading(_("RAID"))),
            VBox(
              Left(raid_name_widget),
              VStretch()
            ),
            HBox(
              HStretch(),
              AddChildrenButton.new(controller, section)
            )
          )
        end

        # @macro seeAbstractWidget
        def init
          raid_name_widget.value = section.device
        end

        # @macro seeAbstractWidget
        def store
          section.device = raid_name_widget.value
        end

      private

        # @return [Y2Autoinstallation::StorageController]
        attr_reader :controller

        # @return [Y2Storage::AutoinstProfile::DriveSection]
        attr_reader :section

        # RAID name input field
        #
        # @return [RaidName]
        def raid_name_widget
          Y2Autoinstallation::Widgets::Storage::RaidName.new
        end
      end
    end
  end
end
