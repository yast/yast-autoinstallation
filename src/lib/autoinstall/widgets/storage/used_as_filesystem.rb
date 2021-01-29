# Copyright (c) [2021] SUSE LLC
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
require "autoinstall/widgets/storage/used_as"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Special subclass of {UsedAs} with only one option
      class UsedAsFilesystem < UsedAs
        # Constructor
        def initialize
          textdomain "autoinst"
          super
        end

        # @macro seeComboBox
        def items
          [
            # TRANSLATORS: option for setting to not use the partition
            [:none, _("Do Not Use")],
            # TRANSLATORS: option for setting the partition to hold a file system
            [:filesystem, _("File System")]
          ]
        end
      end
    end
  end
end
