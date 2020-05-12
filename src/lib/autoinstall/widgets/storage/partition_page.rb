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
require "autoinstall/widgets/storage/partition_general_tab"
require "autoinstall/widgets/storage/partition_usage_tab"

module Y2Autoinstallation
  module Widgets
    module Storage
      # This page allows to edit the information of a partition
      class PartitionPage < ::CWM::Page
        # Constructor
        #
        # @param partition [Presenters::Partition] presenter for a partition section of the profile
        def initialize(partition)
          textdomain "autoinst"
          @partition = partition
          super()
          self.widget_id = "partition_page:#{partition.section_id}"
        end

        # @macro seeAbstractWidget
        def label
          partition.ui_label
        end

        # @macro seeCustomWidget
        def contents
          Top(
            VBox(
              Left(Heading(_("Partition"))),
              Left(tabs)
            )
          )
        end

        def section
          partition.section
        end

      private

        # @return [Presenters::Partition] presenter for the partition section
        attr_reader :partition

        # Tabs to display the partition section data
        #
        # First tab will contain the common options for the partition section (including those that
        # actually depends on the parent section type). The second tab allows to choose the
        # partition usage and its related options.
        #
        # @return [CWM::Tabs]
        def tabs
          CWM::Tabs.new(
            general_tab,
            usage_tab
          )
        end

        # Tab to display common options for all partition sections
        #
        # @return [PartitionGeneralTab]
        def general_tab
          @general_tab ||= PartitionGeneralTab.new(partition)
        end

        # Tab to display options related to the partition section usage
        #
        # @return [PartitionUsageTab]
        def usage_tab
          @usage_tab ||= PartitionUsageTab.new(partition)
        end
      end
    end
  end
end
