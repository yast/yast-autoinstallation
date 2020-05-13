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
require "autoinstall/widgets/storage/filesystem_attrs"
require "autoinstall/widgets/storage/raid_attrs"
require "autoinstall/widgets/storage/lvm_pv_attrs"
require "autoinstall/widgets/storage/lvm_partition_attrs"
require "autoinstall/widgets/storage/encryption_attrs"
require "autoinstall/widgets/storage/size_selector"
require "autoinstall/widgets/storage/used_as"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Tab to manage the partition section options that depends on its usage (file system, LVM PV,
      # RAID member, etc).
      class PartitionUsageTab < ::CWM::Tab
        # Constructor
        #
        # @param partition [Presenters::Partition] presenter for a partition section of the profile
        def initialize(partition)
          textdomain "autoinst"

          @partition = partition
          self.handle_all_events = true
        end

        # @macro seeAbstractWidget
        def label
          # TRANSLATORS: name of the tab to display the partition section options based on its usage
          _("Used as")
        end

        def contents
          VBox(
            HBox(
              HWeight(1, used_as_widget),
              HWeight(2, empty_widget)
            ),
            replace_point,
            encryption_replace_point
          )
        end

        # @macro seeAbstractWidget
        def init
          used_as_widget.value = partition.usage.to_s
          refresh
        end

        # @macro seeAbstractWidget
        def handle(event)
          refresh if event["ID"] == "used_as"

          nil
        end

        # @macro seeAbstractWidget
        def values
          relevant_widgets.reduce({}) do |hsh, widget|
            hsh.merge(widget.values)
          end
        end

        # @macro seeAbstractWidget
        def store
          partition.update(values)
          nil
        end

      private

        # @return [Presenters::Partition] presenter for the partition section
        attr_reader :partition

        # Convenience method to retrieve all widgets holding profile attributes
        #
        # @return [Array<CWW::CustomWidget>]
        def relevant_widgets
          [
            filesystem_widget,
            raid_widget,
            lvm_pv_widget,
            encryption_widget
          ]
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

        # Widget for setting encryption related attributes
        def encryption_widget
          @encryption_widget ||= EncryptionAttrs.new(partition)
        end

        def used_as_widget
          @used_as_widget ||= UsedAs.new
        end

        def replace_point
          @replace_point ||= CWM::ReplacePoint.new(id: "attrs", widget: filesystem_widget)
        end

        def encryption_replace_point
          @encryption_replace_point ||= CWM::ReplacePoint.new(
            id:     "encryption_attrs",
            widget: empty_widget
          )
        end

        def refresh
          update_replace_point
          update_encryption_replace_point
        end

        # Updates replace point with the content corresponding widget for selected type
        def update_replace_point
          replace_point.replace(selected_widget)
        end

        # Returns the selected widget according to the UsedAs widget
        #
        # @return [CWM::AbstractWidget]
        def selected_widget
          send("#{used_as_widget.value}_widget")
        end

        # Displays or hides encryption attrs depending on the selected partition usage
        def update_encryption_replace_point
          if used_as_widget.value == "raid"
            encryption_replace_point.replace(empty_widget)
          else
            encryption_replace_point.replace(encryption_widget)
          end
        end

        # Empty widget
        def empty_widget
          @empty_widget ||= CWM::Empty.new("empty")
        end
      end
    end
  end
end
