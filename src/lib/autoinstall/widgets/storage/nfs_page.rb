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
require "autoinstall/widgets/storage/drive_page"
require "autoinstall/widgets/storage/nfs_name"

module Y2Autoinstallation
  module Widgets
    module Storage
      # This page allows to edit a `drive` section representing an NFS mount
      class NfsPage < DrivePage
        # @see DrivePage#initialize
        def initialize(*args)
          textdomain "autoinst"
          super
        end

        # @macro seeCustomWidget
        def contents
          MarginBox(
            0.5,
            0,
            VBox(
              Left(HSquash(nfs_name_widget)),
              VStretch()
            )
          )
        end

        # @see DrivePage#init
        def init
          nfs_name_widget.value = drive.device
        end

        # @see DrivePage#values
        def values
          { "device" => nfs_name_widget.value }
        end

      private

        # Widget for setting the name of the NFS mount
        def nfs_name_widget
          @nfs_name_widget ||= NfsName.new
        end
      end
    end
  end
end
