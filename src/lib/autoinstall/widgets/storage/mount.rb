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
      # Widget to select the mount point for a file system
      class Mount < CWM::ComboBox
        # Constructor
        def initialize
          textdomain "autoinst"
          super
        end

        def label
          _("Mount Point")
        end

        # @macro seeAbstractWidget
        def opt
          [:editable]
        end

        ITEMS = [
          "",
          "/",
          "/boot",
          "/srv",
          "/tmp",
          "/usr/local",
          "swap"
        ].freeze
        private_constant :ITEMS

        # @macro seeComboBox
        def items
          @items ||= ITEMS.map { |i| [i, i] }
        end
      end
    end
  end
end
