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
require "autoinstall/widgets/storage/label"
require "autoinstall/widgets/storage/mount"
require "autoinstall/widgets/storage/mountby"
require "autoinstall/widgets/storage/mkfs_options"
require "autoinstall/widgets/storage/fstopt"

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
              HWeight(1, mountby_widget),
              HWeight(1, Empty())
            ),
            HBox(
              HWeight(2, fstab_options_widget),
              HWeight(1, Empty())
            ),
            HBox(
              HWeight(1, mkfs_options_widget),
              HWeight(2, Empty())
            )
          )
        end

        # @macro seeAbstractWidget
        def init
          filesystem_widget.value    = section.filesystem.to_s if section.filesystem
          label_widget.value         = section.label
          mount_point_widget.value   = section.mount
          mountby_widget.value       = section.mountby
          fstab_options_widget.value = section.fstab_options
          mkfs_options_widget.value  = section.mkfs_options
        end

        # Returns the widgets values
        #
        # @return [Hash<String,Object>]
        def values
          {
            "filesystem"    => filesystem_widget.value&.to_sym,
            "label"         => label_widget.value,
            "mount"         => mount_point_widget.value,
            "mountby"       => mountby_widget.value&.to_sym,
            "fstab_options" => fstab_options_widget.value,
            "mkfs_options"  => mkfs_options_widget.value
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

        # Widget for selecting the partition mount point
        def mount_point_widget
          @mount_point_widget ||= Mount.new
        end

        # Widget for selecting the partition mount type
        def mountby_widget
          @mountby_widget ||= Mountby.new
        end

        # Widget for specifying fstab options
        def fstab_options_widget
          @fstab_options_widget ||= Fstopt.new
        end

        # Widget for specifying mkfs command options
        def mkfs_options_widget
          @mkfs_options_widget ||= MkfsOptions.new
        end
      end
    end
  end
end
