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
require "cwm/tabs"
require "cwm/replace_point"
require "cwm/common_widgets"
require "autoinstall/widgets/storage/partition_tab"
require "autoinstall/widgets/storage/filesystem_attrs"
require "autoinstall/widgets/storage/raid_attrs"
require "autoinstall/widgets/storage/lvm_pv_attrs"
require "autoinstall/widgets/storage/bcache_backing_attrs"
require "autoinstall/widgets/storage/btrfs_member_attrs"
require "autoinstall/widgets/storage/used_as"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Tab to manage the partition section options that depend on its usage (file system, LVM PV,
      # RAID member, etc).
      class PartitionUsageTab < PartitionTab
        # Constructor
        #
        # @param partition [Presenters::Partition] presenter for a partition section of the profile
        def initialize(partition)
          textdomain "autoinst"
          super
          self.handle_all_events = true
        end

        # @macro seeAbstractWidget
        def label
          # TRANSLATORS: name of the tab to display the partition section options based on its usage
          _("Used As")
        end

        # @macro seeAbstractWidget
        def init
          used_as_widget.value = partition.usage
          update_replace_point
        end

        # @macro seeAbstractWidget
        def handle(event)
          update_replace_point if event["ID"] == "used_as"

          nil
        end

        # @see PartitionTab#visible_widgets
        def visible_widgets
          [
            Left(used_as_widget),
            replace_point
          ]
        end

        # @see PartitionTab#widgets
        def widgets
          [
            filesystem_widget,
            raid_widget,
            lvm_pv_widget,
            bcache_backing_widget,
            btrfs_member_widget
          ]
        end

      private

        # Widget grouping related file system attributes
        def filesystem_widget
          @filesystem_widget ||= FilesystemAttrs.new(partition)
        end

        # Widget grouping related RAID attributes
        def raid_widget
          @raid_widget ||= RaidAttrs.new(partition)
        end

        # Widget grouping related LVM PV attributes
        def lvm_pv_widget
          @lvm_pv_widget ||= LvmPvAttrs.new(partition)
        end

        # Widget grouping attributes related to a bcache backing device
        def bcache_backing_widget
          @bcache_backing_widget ||= BcacheBackingAttrs.new(partition)
        end

        # Widget grouping attributes related to a Btrfs member
        def btrfs_member_widget
          @btrfs_member_widget ||= BtrfsMemberAttrs.new(partition)
        end

        # Widget for choosing the partition usage
        def used_as_widget
          @used_as_widget ||= UsedAs.new
        end

        def replace_point
          @replace_point ||= CWM::ReplacePoint.new(id: "attrs", widget: empty_widget)
        end

        # Updates replace point with the content corresponding widget for selected type
        def update_replace_point
          replace_point.replace(selected_widget)
        end

        # Returns the selected widget according to the UsedAs widget
        #
        # @return [CWM::AbstractWidget]
        def selected_widget
          used_as = used_as_widget.value

          return empty_widget if used_as == :none

          send("#{used_as}_widget")
        end

        # Empty widget
        def empty_widget
          @empty_widget ||= CWM::Empty.new("empty")
        end
      end
    end
  end
end
