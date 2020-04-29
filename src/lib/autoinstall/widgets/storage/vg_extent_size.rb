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
require "autoinstall/widgets/storage/size_selector"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Widget for the LVM VG extent size
      class VgExtentSize < SizeSelector
        # Constructor
        def initialize
          textdomain "autoinst"
          super
        end

        # @macro seeAbstractWidget
        def label
          # TRANSLATORS: field to enter the extent size of a new volume group
          _("Physical Extent Size")
        end

        def sizes
          ["1 MiB", "2 MiB", "4 MiB", "8 MiB", "16 MiB", "32 MiB", "64 MiB"]
        end

        def include_max?
          false
        end

        def include_auto?
          false
        end
      end
    end
  end
end
