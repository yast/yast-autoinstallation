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
require "autoinstall/widgets/storage/enable_snapshots"
require "y2storage"
require "cwm/page"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Base class for all the pages allowing to edit a <drive> section
      class DrivePage < ::CWM::Page
        # Constructor
        #
        # @param drive [Presenters::Drive] presenter for the drive section of the profile
        def initialize(drive)
          textdomain "autoinst"
          @drive = drive
          super()
          self.widget_id = "drive_page:#{drive.section_id}"
          self.handle_all_events = true
        end

        # @macro seeAbstractWidget
        def label
          drive.ui_label
        end

        # @macro seeCustomWidget
        def contents
          MarginBox(
            0.5,
            0,
            VBox(
              # Specific page content
              *widgets.flat_map { |widget| [Left(widget), VSpacing(0.5)] },
              # Common content
              Left(enable_snapshots_widget),
              VStretch()
            )
          )
        end

        # @macro seeAbstractWidget
        def init
          enable_snapshots_widget.value = drive.enable_snapshots
          init_widgets_values
        end

        # @macro seeAbstractWidget
        def store
          drive.update(values)
        end

        def values
          widgets_values.merge(
            "enable_snapshots" => enable_snapshots_widget.value
          )
        end

        # Specific page widgets
        #
        # This method must be defined by derived pages
        #
        # @return [Array<Yast::Term, CWM::AbstractWidget]
        def widgets
          []
        end

        # Returns the widgets values
        #
        # This method must be defined by derived pages
        #
        # @return [Hash<String,Object>]
        def widgets_values
          {}
        end

        # Initialize the widgets values
        #
        # This method must be defined by derived pages
        def init_widgets_values
          nil
        end

        # Drive section that is being edited
        #
        # @return [Y2Storage::AutoinstProfile::DriveSection]
        def section
          drive.section
        end

      private

        # @return [Presenters::Drive]
        attr_reader :drive

        def enable_snapshots_widget
          @enable_snapshots_widget ||= EnableSnapshots.new
        end
      end
    end
  end
end
