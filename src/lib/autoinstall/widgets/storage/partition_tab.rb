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

module Y2Autoinstallation
  module Widgets
    module Storage
      # Base class to create tabs for organizing the partition section attributes
      class PartitionTab < ::CWM::Tab
        # Constructor
        #
        # @param partition [Presenters::Partition] presenter for a partition section of the profile
        def initialize(partition)
          textdomain "autoinst"

          @partition = partition
        end

        # @macro seeAbstractWidget
        def label
          ""
        end

        def contents
          MarginBox(
            0.4,
            0.4,
            VBox(
              *visible_widgets.flat_map { |widget| [Left(widget), VSpacing(0.5)] }.tap(&:pop),
              VStretch()
            )
          )
        end

        # @macro seeAbstractWidget
        def store
          attrs = widgets.reduce({}) { |result, widget| result.merge(widget.values) }
          partition.update(attrs)
          nil
        end

        # Return widgets to be shown
        #
        # This method must be defined by derived tabs
        #
        # @return [Array<Yast::Term, CWM::AbstractWidget]
        def visible_widgets
          []
        end

        # Returns all widgets managed by the tab
        #
        # This method must be defined by derived tabs since it is needed by the #store method to
        # properly update the partition section setting only relevant attributes.
        #
        # @see Presenters::Section#update
        #
        # @return [Array<Yast::Term, CWM::AbstractWidget]
        def widgets
          []
        end

      private

        # @return [Presenters::Partition] presenter for the partition section
        attr_reader :partition
      end
    end
  end
end
