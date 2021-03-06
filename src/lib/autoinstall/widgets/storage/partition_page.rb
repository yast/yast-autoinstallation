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
          Left(tabs)
        end

        # Returns the partition section
        #
        # Needed by {OverviewTreePager#initial_page }
        #
        # @return [Y2Storage::AutoinstProfile::PartitionSection] the partition section
        def section
          partition.section
        end

      private

        # @return [Presenters::Partition] presenter for the partition section
        attr_reader :partition

        # Tabs to display the partition section data
        #
        # Normally, the first tab contains common options for a partition section (including those
        # that depend on the parent section type). The second one allows to choose the partition
        # usage and its related options. In some cases, that second tab is enough.
        #
        # @return [CWM::Tabs]
        def tabs
          if partition.fstab_based?
            CWM::Tabs.new(usage_tab)
          else
            CWM::Tabs.new(
              general_tab,
              usage_tab
            )
          end
        end

        # Tab to display common options for all partition sections
        def general_tab
          @general_tab ||= PartitionGeneralTab.new(partition)
        end

        # Tab to display options related to the partition section usage
        def usage_tab
          @usage_tab ||= PartitionUsageTab.new(partition)
        end
      end
    end
  end
end
