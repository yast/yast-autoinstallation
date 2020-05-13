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
require "cwm/custom_widget"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Determines how a partition will be used
      class UsedAs < CWM::ComboBox
        # Constructor
        def initialize
          textdomain "autoinst"
          super()
          self.widget_id = "used_as"
        end

        # @macro seeAbstractWidget
        def opt
          [:notify]
        end

        # @macro seeAbstractWidget
        def label
          _("Used as")
        end

        # @macro seeComboBox
        def items
          # FIXME: uncomment when support for each type is added
          [
            # TRANSLATORS: option for setting to not use the partition
            [:none, _("Do not use")],
            # TRANSLATORS: option for setting the partition to hold a file system
            [:filesystem, _("File system")],
            # TRANSLATORS: option for setting the partition as a RAID member
            [:raid, _("RAID member")],
            # TRANSLATORS: option for setting the partition as an LVM physical volume
            [:lvm_pv, _("LVM physical volume")]
            # ["bcache_caching", _("Bcache caching device")],
            # ["bcache_backing", _("Bcache backing device")],
            # ["btrfs_member", _("Btrfs multi-device member")]
          ]
        end
      end
    end
  end
end
