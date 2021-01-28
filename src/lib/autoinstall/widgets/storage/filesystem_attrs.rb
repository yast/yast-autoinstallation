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
require "autoinstall/widgets/storage/create_subvolumes"

module Y2Autoinstallation
  module Widgets
    module Storage
      # File system specific widgets
      #
      # It groups those attributes that are specific for a partition being used as file system.
      #
      # @see PartitionUsageTab
      class FilesystemAttrs < CWM::CustomWidget
        # Constructor
        #
        # @param section [Presenters::Partition] presenter for the partition section
        def initialize(section)
          textdomain "autoinst"
          super()
          @section = section
          self.handle_all_events = true
        end

        # @macro seeAbstractWidget
        def label
          ""
        end

        # @macro seeCustomWidget
        def contents
          VBox(
            *mount_widgets,
            VSpacing(0.5),
            *format_widgets
          )
        end

        # @macro seeAbstractWidget
        def init
          filesystem_widget.value        = section.filesystem
          label_widget.value             = section.label
          mount_point_widget.value       = section.mount
          mountby_widget.value           = section.mountby
          fstab_options_widget.value     = section.fstab_options
          mkfs_options_widget.value      = section.mkfs_options
          create_subvolumes_widget.value = section.create_subvolumes

          set_btrfs_attrs_status
        end

        # Returns the widgets values
        #
        # @return [Hash<String,Object>]
        def values
          {
            "filesystem"        => filesystem_widget.value,
            "label"             => label_widget.value,
            "mount"             => mount_point_widget.value,
            "mountby"           => mountby_widget.value,
            "fstab_options"     => fstab_options_widget.value,
            "mkfs_options"      => mkfs_options_widget.value,
            "create_subvolumes" => btrfs? ? create_subvolumes_widget.value : nil
          }
        end

        # @macro seeAbstractWidget
        def handle(event)
          set_btrfs_attrs_status if event["ID"] == filesystem_widget.widget_id

          nil
        end

      private

        # @return [Presenters::Partition] presenter for the partition section
        attr_reader :section

        # Whether selected files ystem is Btrfs
        #
        # @return [Boolean] true if selected file system is Btrfs; false otherwise
        def btrfs?
          filesystem_widget.value == :btrfs
        end

        # Update the Btrfs attrs status according to the value of #filesystem_widget
        def set_btrfs_attrs_status
          if btrfs?
            create_subvolumes_widget.enable
          else
            create_subvolumes_widget.disable
          end
        end

        # Widget for settings the filesystem type
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

        # Widget for setting if Btrfs subvolumes should be created or not
        def create_subvolumes_widget
          @create_subvolumes_widget ||= CreateSubvolumes.new
        end

        # @see #contents
        def format_widgets
          [
            Left(
              HBox(
                filesystem_widget,
                HSpacing(2),
                HSquash(MinWidth(15, label_widget))
              )
            ),
            VSpacing(0.5),
            Left(
              HSquash(MinWidth(35, mkfs_options_widget))
            ),
            VSpacing(0.5),
            Left(create_subvolumes_widget)
          ]
        end

        # @see #contents
        def mount_widgets
          [
            Left(
              HBox(
                HSquash(MinWidth(15, mount_point_widget)),
                HSpacing(2),
                mountby_widget,
                HSpacing(2),
                HSquash(fstab_options_widget)
              )
            )
          ]
        end
      end
    end
  end
end
