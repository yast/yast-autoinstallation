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
require "cwm/custom_widget"
require "autoinstall/widgets/storage/filesystem"
require "autoinstall/widgets/storage/mount_point"
require "autoinstall/widgets/storage/format_filesystem"

module Y2Autoinstallation
  module Widgets
    module Storage
      # File system specific widgets
      #
      # This is a custom widget that groups those that are file system specific.
      class FilesystemAttrs < CWM::CustomWidget
        # Constructor
        #
        # @param controller [Y2Autoinstallation::StorageController] UI controller
        # @param section [Y2Storage::AutoinstProfile::PartitionSection] Partition section
        #   of the profile
        def initialize(controller, section)
          super()
          textdomain "autoinst"
          @controller = controller
          @section = section
        end

        # @macro seeAbstractWidget
        def label
          ""
        end

        # @macro seeCustomWidget
        def contents
          VBox(
            Left(filesystem_widget),
            Left(mount_point_widget),
            Left(format_filesystem_widget)
          )
        end

        # @macro seeAbstractWidget
        def init
          format_filesystem_widget.value = !!section.format
          # FIXME: Disable the filesystem if format is set to false
          filesystem_widget.value = section.filesystem.to_s if section.filesystem
          mount_point_widget.value = section.mount
        end

        # Returns the widgets values
        #
        # @return [Hash<String,Object>]
        def values
          widget_values = {
            "format" => format_filesystem_widget.value,
            "mount"  => mount_point_widget.value
          }

          if widget_values["format"] && filesystem_widget.value
            widget_values["filesystem"] = filesystem_widget.value.to_sym
          end

          widget_values
        end

      private

        attr_reader :controller, :section

        # Mount point widget
        #
        # @return [MountPoint]
        def mount_point_widget
          @mount_point_widget ||= MountPoint.new
        end

        # Filesystem type widget
        def filesystem_widget
          @filesystem_widget ||= Filesystem.new
        end

        # Format filesystem widget
        def format_filesystem_widget
          @format_filesystem_widget ||= FormatFilesystem.new
        end
      end
    end
  end
end
