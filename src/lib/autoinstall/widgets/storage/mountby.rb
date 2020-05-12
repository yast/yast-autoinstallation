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
require "y2storage"
require "cwm/common_widgets"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Selector widget to set the partition mount type
      class Mountby < CWM::ComboBox
        # Constructor
        def initialize
          textdomain "autoinst"
          super
        end

        # @macro seeAbstractWidget
        def label
          _("Mount by")
        end

        # @macro seeComboBox
        def items
          @items ||= [
            ["", ""],
            *Y2Storage::Filesystems::MountByType.all.map { |i| [i.to_s, i.to_human_string] }
          ]
        end

        # Returns selected type
        #
        # @return [String, nil] selected type; nil if none
        def value
          result = super

          result.to_s.empty? ? nil : result
        end
      end
    end
  end
end
