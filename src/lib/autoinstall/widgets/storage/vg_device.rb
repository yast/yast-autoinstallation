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
      # Widget to select the physical volume for a volume group
      #
      # It corresponds to the `device` element in the profile.
      class VgDevice < CWM::ComboBox
        def initialize
          textdomain "autoinst"
          super
        end

        # @macro seeAbstractWidget
        def label
          _("Device")
        end

        # @macro seeAbstractWidget
        def opt
          [:editable]
        end

        def items=(devices)
          change_items(devices.map { |i| [i, i] })
        end
      end
    end
  end
end
