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
require "autoinstall/widgets/storage/mount_point"

module Y2Autoinstallation
  module Widgets
    module Storage
      # This page allows to edit the information of a partition
      #
      # Depending on its usage (file system, LVM PV, RAID member, etc.) it may
      # display a different set of widgets.
      class PartitionPage < ::CWM::Page
        # @return [Y2Storage::AutoinstProfile::PartitionSection] Partition section
        attr_reader :section

        # Constructor
        #
        # @param section [Y2Storage::AutoinstProfile::PartitionSection] Partition section
        #   of the profile
        def initialize(section)
          textdomain "autoinst"
          @section = section
          super()
          self.widget_id = "partition_page:#{object_id}"
        end

        # @macro abstractWidget
        def label
          if section.mount && !section.mount.empty?
            format(_("Partition at %{mount_point}"), mount_point: section.mount)
          else
            _("Partition")
          end
        end

        # @macro customWidget
        def contents
          VBox(
            Left(Heading(label)),
            mount_point_widget
          )
        end

      private

        # Mount point widget
        #
        # @return [MountPoint]
        def mount_point_widget
          return @mount_point_widget if @mount_point_widget
          @mount_point_widget = MountPoint.new(initial: section.mount)
        end
      end
    end
  end
end
