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

module Y2Autoinstallation
  module Widgets
    module Storage
      # Button to remove the selected section
      class DeleteSectionButton < CWM::PushButton
        # Constructor
        #
        # @param controller [Y2Autoinstallation::StorageController] UI controller
        def initialize(controller)
          super()
          textdomain "autoinst"
          @controller = controller
        end

        # @macro seeAbstractWidget
        def label
          _("Delete")
        end

        # @macro seeAbstractWidget
        def handle
          controller.delete_section
          :redraw
        end

      private

        # @return [Y2Autoinstallation::StorageController]
        attr_reader :controller
      end
    end
  end
end
