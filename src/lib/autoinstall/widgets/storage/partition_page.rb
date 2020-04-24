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
require "cwm/replace_point"
require "cwm/common_widgets"
require "autoinstall/widgets/storage/add_children_button"
require "autoinstall/widgets/storage/filesystem_attrs"
require "autoinstall/widgets/storage/raid_attrs"
require "autoinstall/widgets/storage/lvm_pv_attrs"
require "autoinstall/widgets/storage/lvm_partition_attrs"
require "autoinstall/widgets/storage/used_as"

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
          self.handle_all_events = true
        end

        # @macro seeAbstractWidget
        def label
          send("label_as_#{controller.partition_usage(section)}")
        end

        # @macro seeCustomWidget
        def contents
          VBox(
            Left(Heading(_("Partition"))),
            VBox(
              Left(drive_dependent_attrs_widget),
              Left(used_as_widget),
              Left(replace_point),
              VStretch()
            ),
            HBox(
              HStretch(),
              AddChildrenButton.new(controller, drive)
            )
          )
        end

        # @macro seeAbstractWidget
        def init
          used_as_widget.value = controller.partition_usage(section).to_s
          update_replace_point
        end

        # @macro seeAbstractWidget
        def handle(event)
          update_replace_point if event["ID"] == "used_as"
          nil
        end

        # @macro seeAbstractWidget
        def store
          values = selected_widget.values

          if drive_dependent_attrs_widget.respond_to?(:values)
            values.merge!(drive_dependent_attrs_widget.values)
          end

          controller.update_partition(section, values)
          nil
        end

      private

        # @return [Y2Autoinstallation::StorageController]
        attr_reader :controller

        # @return [Y2Storage::AutoinstProfile::DriveSection]
        attr_reader :drive

        # @return [Y2Storage::AutoinstProfile::PartitionSection]
        attr_reader :section

        def used_as_widget
          @used_as_widget ||= UsedAs.new
        end

        def filesystem_widget
          @filesystem_widget ||= FilesystemAttrs.new(controller, section)
        end

        def raid_widget
          @raid_widget ||= RaidAttrs.new(controller, section)
        end

        def lvm_pv_widget
          @lvm_pv_widget ||= LvmPvAttrs.new(controller, section)
        end

        def drive_dependent_attrs_widget
          @drive_dependent_attrs_widget ||=
            begin
              drive_type = drive.type.to_s.delete_prefix("CT_")
              widget = "#{drive_type.capitalize}PartitionAttrs"
              Y2Autoinstallation::Widgets::Storage.const_get(widget).new(controller, section)
            rescue NameError
              CWM::Empty.new("drive_dependent_attrs")
            end
        end

        def replace_point
          @replace_point ||= CWM::ReplacePoint.new(id: "attrs", widget: filesystem_widget)
        end

        # Updates the replace point with the content corresponding to the UsedAs widget value
        def update_replace_point
          replace_point.replace(selected_widget)
        end

        # Returns the selected widget according to the UsedAs widget
        #
        # @return [CWM::AbstractWidget]
        def selected_widget
          send("#{used_as_widget.value}_widget")
        end

        # Returns the label when the partition is used as file system
        #
        # @return [String]
        def label_as_filesystem
          if section.mount && !section.mount.empty?
            format(_("Partition at %{mount_point}"), mount_point: section.mount)
          else
            _("Partition")
          end
        end

        # Returns the label when the partition is used as RAID member
        #
        # @return [String]
        def label_as_raid
          format(_("Part of %{device}"), device: section.raid_name)
        end

        # Returns the label when the partition is used as LVM PV
        #
        # @return [String]
        def label_as_lvm_pv
          format(_("Partition for PV %{lvm_group}"), lvm_group: section.lvm_group)
        end
      end
    end
  end
end
