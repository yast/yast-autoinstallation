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
require "autoinstall/widgets/storage/label"

module Y2Autoinstallation
  module Widgets
    module Storage
      # File system specific widgets
      #
      # This is a custom widget that groups those that are file system specific.
      class FilesystemAttrs < CWM::CustomWidget
        # Constructor
        #
        # @param section [Presenters::Partition] presenter for the partition section
        def initialize(section)
          super()
          textdomain "autoinst"
          @section = section
        end

        # @macro seeAbstractWidget
        def label
          ""
        end

        # @macro seeCustomWidget
        def contents
          VBox(
            HBox(
              HWeight(1, filesystem_widget),
              HWeight(1, label_widget),
              HWeight(1, Empty())
            ),
            HBox(
              HWeight(1, mount_point_widget),
              HWeight(2, Empty())
            )
          )
        end

        # @macro seeAbstractWidget
        def init
          filesystem_widget.value  = section.filesystem.to_s if section.filesystem
          mount_point_widget.value = section.mount
          label_widget.value       = section.label
        end

        # Returns the widgets values
        #
        # @return [Hash<String,Object>]
        def values
          {
            "filesystem" => filesystem_widget.value&.to_sym,
            "label"      => label_widget.value,
            "mount"      => mount_point_widget.value
          }
        end

      private

        # @return [Presenters::Partition] presenter for the partition section
        attr_reader :section

        # Filesystem type widget
        def filesystem_widget
          @filesystem_widget ||= Filesystem.new
        end

        # Widget for setting the partition label
        def label_widget
          @label_widget ||= Label.new
        end

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
