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
require "cwm/dialog"
require "autoinstall/widgets/storage/overview_tree_pager"
require "autoinstall/storage_controller"

Yast.import "Label"
Yast.import "Popup"

module Y2Autoinstallation
  module Dialogs
    # Dialog to set up the partition plan
    #
    # @example Edit a partitioning section
    #   devicegraph = Y2Storage::StorageManager.instance.probed
    #   partitioning = Y2Storage::Autoinst::PartitioningSection.new_from_storage(devicegraph)
    #   result = Y2Autoinstallation::Dialogs::Storage.new(partitioning).run
    #
    # @example Start with an empty section
    #   result = Y2Autoinstallation::Dialogs::Storage.new
    class Storage < CWM::Dialog
      # @return [Y2Storage::AutoinstProfile::PartitioningSection]
      #   Partitioning section of the profile
      attr_reader :partitioning

      # Constructor
      #
      # @param partitioning [Y2Storage::AutoinstProfile::PartitioningSection]
      #   Partitioning section of the profile
      def initialize(partitioning = Y2Storage::AutoinstProfile::PartitioningSection.new)
        textdomain "autoinst"
        @controller = Y2Autoinstallation::StorageController.new(partitioning)
      end

      # @macro seeDialog
      def contents
        MarginBox(
          0.5,
          0.5,
          Y2Autoinstallation::Widgets::Storage::OverviewTreePager.new(controller)
        )
      end

      # @macro seeDialog
      def next_button
        Yast::Label.FinishButton
      end

      # @macro seeDialog
      def abort_button
        ""
      end

      # @macro seeDialog
      def back_button
        Yast::Label.CancelButton
      end

      # @macro seeDialog
      def next_handler
        @partitioning = controller.partitioning
        true
      end

      # @macro seeDialog
      def back_handler
        Yast::Popup.ReallyAbort(controller.modified?)
      end

      def should_open_dialog?
        true
      end

    private

      attr_reader :controller

      # CWM show loop
      #
      # This method is redefined to keep the dialog in a loop if a
      # `redraw` is needed.
      def cwm_show
        loop do
          result = super
          return result if result != :redraw
        end
      end
    end
  end
end
