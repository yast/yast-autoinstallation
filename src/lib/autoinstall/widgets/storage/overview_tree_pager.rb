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

require "cwm"
require "cwm/tree_pager"
require "autoinstall/widgets/storage/overview_tree"
require "autoinstall/widgets/storage/disk_page"
require "autoinstall/widgets/storage/partition_page"
require "autoinstall/widgets/storage/add_drive_button"
require "autoinstall/ui_state"

module Y2Autoinstallation
  module Widgets
    module Storage
      class OverviewTreePager < CWM::TreePager
        # Constructor
        #
        # @param controller [Y2Autoinstallation::StorgeController] UI controller
        def initialize(controller)
          textdomain("autoinst")
          @controller = controller

          super(tree)
        end

        def contents
          VBox(
            super,
            Left(AddDriveButton.new(controller))
          )
        end

        # @return [Array<CWM::PagerTreeItem>] List of tree items
        def items
          controller.partitioning.drives.each_with_object([]) do |drive, all|
            all << drive_item(drive)
          end
        end

        # Switch to the given page
        #
        # It redefines the original implementation to save the current
        # page and refresh the tree.
        #
        # @param page [CWM::Page] Page to change to
        def switch_page(page)
          UIState.instance.go_to_tree_node(page)
          tree.change_items(items)
          super
        end

        # Ensures the tree is properly initialized according to the UI state after
        # a redraw
        def initial_page
          UIState.instance.find_tree_node(@pages) || super
        end

      private

        # @return [Y2Autoinstallation::StorageController]
        attr_reader :controller

        def tree
          @tree ||= OverviewTree.new(items)
        end

        # Returns the drive item for the given section
        #
        # @param section [Y2Storage::AutoinstProfile::DriveSection] Drive section
        # @return [CWM::PagerTreeItem] Tree item
        def drive_item(section)
          case section.type
          when :CT_DISK
            disk_item(section)
          end
        end

        # @param section [Y2Storage::AutoinstProfile::DriveSection] Drive section corresponding
        #   to a disk
        def disk_item(section)
          children = section.partitions.map do |part|
            part_page = Y2Autoinstallation::Widgets::Storage::PartitionPage.new(
              controller, section, part
            )
            CWM::PagerTreeItem.new(part_page)
          end
          page = Y2Autoinstallation::Widgets::Storage::DiskPage.new(controller, section)
          CWM::PagerTreeItem.new(page, children: children)
        end
      end
    end
  end
end
