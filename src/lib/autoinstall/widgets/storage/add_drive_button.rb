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
require "cwm/common_widgets"
require "autoinstall/presenters"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Button to add new drive sections
      #
      # This button allows to add new drive sections of different types
      # (`CT_DISK`, `CT_LVM`, `CT_RAID`, etc.).
      class AddDriveButton < CWM::MenuButton
        include Yast::Logger

        # Constructor
        #
        # @param controller [Y2Autoinstallation::StorageController] UI controller
        def initialize(controller)
          textdomain "autoinst"
          super()
          @controller = controller
          self.handle_all_events = true
        end

        # @macro seeAbstractWidget
        def label
          _("Add Drive")
        end

        # Returns the list of possible actions
        #
        # @return [Array<Symbol,String>]
        def items
          Presenters::DriveType.all.map do |type|
            [:"add_#{type.to_sym}", type.label]
          end
        end

        # Handles the events
        #
        # @param event [Hash] Event to handle
        def handle(event)
          event_id = event["ID"].to_s
          return unless event_id.start_with?("add_")

          type = event_id.split("_", 2).last
          controller.add_drive(Presenters::DriveType.find(type))
          :redraw
        end

      private

        # @return [Y2Autoinstallation::StorageController]
        attr_reader :controller
      end
    end
  end
end
