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
require "autoinstall/widgets/storage/filesystem_attrs"
require "autoinstall/widgets/storage/raid_attrs"
require "autoinstall/widgets/storage/lvm_pv_attrs"
require "autoinstall/widgets/storage/size_selector"
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
        # @param partition [Presenters::Partition] presenter for a partition section of the profile
        def initialize(partition)
          textdomain "autoinst"
          @partition = partition
          super()
          self.widget_id = "partition_page:#{partition.section_id}"
          self.handle_all_events = true
        end

        # @macro seeAbstractWidget
        def label
          partition.ui_label
        end

        # @macro seeCustomWidget
        def contents
          VBox(
            Left(Heading(_("Partition"))),
            HBox(
              HWeight(1, size_widget),
              HWeight(2, HStretch())
            ),
            Left(drive_dependent_attrs_widget),
            Left(used_as_widget),
            Left(replace_point),
            VStretch()
          )
        end

        # @macro seeAbstractWidget
        def init
          size_widget.value = partition.size
          used_as_widget.value = partition.usage.to_s
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
          values["size"] = size_widget.value

          if drive_dependent_attrs_widget.respond_to?(:values)
            values.merge!(drive_dependent_attrs_widget.values)
          end

          partition.update(values)
          nil
        end

        def section
          partition.section
        end

      private

        # @return [Presenters::Partition] presenter for the partition section
        attr_reader :partition

        def size_widget
          @size_widget ||= SizeSelector.new
        end

        def used_as_widget
          @used_as_widget ||= UsedAs.new
        end

        def filesystem_widget
          @filesystem_widget ||= FilesystemAttrs.new(partition)
        end

        def raid_widget
          @raid_widget ||= RaidAttrs.new(partition)
        end

        def lvm_pv_widget
          @lvm_pv_widget ||= LvmPvAttrs.new(partition)
        end

        def drive_dependent_attrs_widget
          @drive_dependent_attrs_widget ||=
            begin
              drive_type = partition.drive_type.to_s
              widget = "#{drive_type.capitalize}PartitionAttrs"
              Y2Autoinstallation::Widgets::Storage.const_get(widget).new(partition)
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
      end
    end
  end
end
