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
require "autoinstall/widgets/storage/raid_page"
require "autoinstall/widgets/storage/lvm_page"
require "autoinstall/widgets/storage/bcache_page"
require "autoinstall/widgets/storage/btrfs_page"
require "autoinstall/widgets/storage/partition_page"
require "autoinstall/widgets/storage/add_drive_button"
require "autoinstall/widgets/storage/add_partition_button"
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
            Left(
              HBox(
                AddDriveButton.new(controller),
                AddPartitionButton.new(controller)
              )
            )
          )
        end

        # @return [Array<CWM::PagerTreeItem>] List of tree items
        def items
          controller.drive_presenters.each_with_object([]) do |drive, all|
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
          controller.section = page.section
          tree.change_items(items)
          super
        end

        # Ensures the tree is properly initialized according to the UI state after
        # a redraw
        def initial_page
          controller_page || UIState.instance.find_tree_node(@pages) || super
        end

      private

        # @return [Y2Autoinstallation::StorageController]
        attr_reader :controller

        def tree
          @tree ||= OverviewTree.new(items)
        end

        def controller_page
          return nil unless controller.section

          @pages.find { |page| page.section == controller.section }
        end

        # Returns the drive item for the given section
        #
        # @param section [Y2Storage::AutoinstProfile::DriveSection] Drive section
        # @return [CWM::PagerTreeItem] Tree item
        def drive_item(section)
          page_klass = page_klass_for(section.type)
          page = page_klass.new(section)
          CWM::PagerTreeItem.new(page, children: partition_items(section))
        end

        # Determines the widget class for the given type
        def page_klass_for(type)
          Y2Autoinstallation::Widgets::Storage.const_get("#{type.to_s.capitalize}Page")
        rescue NameError
          Y2Autoinstallation::Widgets::Storage::DiskPage
        end

        # Returns the pages for a given list of partition sections
        #
        # @param drive [Presenters::Drive]
        #   List of partition partition sections
        def partition_items(drive)
          drive.partitions.map do |part|
            part_page = Y2Autoinstallation::Widgets::Storage::PartitionPage.new(part)
            CWM::PagerTreeItem.new(part_page)
          end
        end
      end
    end
  end
end
