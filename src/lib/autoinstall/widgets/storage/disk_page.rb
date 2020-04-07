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
require "autoinstall/widgets/storage/disk_device"

module Y2Autoinstallation
  module Widgets
    module Storage
      # This page allows to edit usage information for a disk
      class DiskPage < ::CWM::Page
        # @return [Y2Storage::AutoinstProfile::DriveSection] Drive section corresponding
        #   to a disk
        attr_reader :section

        # Constructor
        #
        # @param section [Y2Storage::AutoinstProfile::DriveSection] Drive section corresponding
        #   to a disk
        def initialize(section)
          textdomain "autoinst"
          @section = section
          super()
          self.widget_id = "disk_page:#{object_id}"
        end

        # @macro seeAbstractWidget
        def label
          if section.device && !section.device.empty?
            format(_("Disk %{device}"), device: section.device)
          else
            format(_("Disk"))
          end
        end

        # @macro seeCustomWidget
        def contents
          VBox(
            Left(Heading(label)),
            disk_device_widget,
          )
        end

        # @macro seeAbstractWidget
        def store
          section.device = disk_device_widget.value
        end

      private

        # Disk device selector
        #
        # @return [DiskDevice]
        def disk_device_widget
          DiskDevice.new(initial: section.device)
        end
      end
    end
  end
end
