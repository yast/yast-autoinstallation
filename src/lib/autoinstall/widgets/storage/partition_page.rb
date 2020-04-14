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
require "autoinstall/widgets/storage/add_children_button"
require "autoinstall/widgets/storage/mount_point"

module Y2Autoinstallation
  module Widgets
    module Storage
      # This page allows to edit the information of a partition
      #
      # Depending on its usage (file system, LVM PV, RAID member, etc.) it may
      # display a different set of widgets.
      class PartitionPage < ::CWM::Page
        # Constructor
        #
        # @param controller [Y2Autoinstallation::StorageController] UI controller
        # @param drive [Y2Storage::AutoinstProfile::DriveSection] Drive section
        #   of the profile
        # @param section [Y2Storage::AutoinstProfile::PartitionSection] Partition section
        #   of the profile
        def initialize(controller, drive, section)
          textdomain "autoinst"
          @controller = controller
          @section = section
          @drive = drive
          super()
          self.widget_id = "partition_page:#{section.object_id}"
        end

        # @macro seeAbstractWidget
        def label
          if section.mount && !section.mount.empty?
            format(_("Partition at %{mount_point}"), mount_point: section.mount)
          else
            _("Partition")
          end
        end

        # @macro seeCustomWidget
        def contents
          VBox(
            Left(Heading(_("Partition"))),
            Left(
              VBox(
                mount_point_widget,
                VStretch()
              )
            ),
            HBox(
              HStretch(),
              AddChildrenButton.new(controller, drive)
            )
          )
        end

        # @macro seeAbstractWidget
        def init
          mount_point_widget.value = section.mount
        end

        # @macro seeAbstractWidget
        def store
          section.mount = mount_point_widget.value
        end

      private

        # @return [Y2Autoinstallation::StorageController]
        attr_reader :controller

        # @return [Y2Storage::AutoinstProfile::DriveSection]
        attr_reader :drive

        # @return [Y2Storage::AutoinstProfile::PartitionSection]
        attr_reader :section

        # Mount point widget
        #
        # @return [MountPoint]
        def mount_point_widget
          @mount_point_widget ||= MountPoint.new
        end
      end
    end
  end
end
