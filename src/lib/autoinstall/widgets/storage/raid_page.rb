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
require "autoinstall/widgets/storage/drive_page"
require "autoinstall/widgets/storage/raid_name"
require "autoinstall/widgets/storage/md_level"
require "autoinstall/widgets/storage/chunk_size"
require "autoinstall/widgets/storage/parity_algorithm"

module Y2Autoinstallation
  module Widgets
    module Storage
      # This page allows to edit a `drive` section representing a RAID device
      class RaidPage < DrivePage
        # @see DrivePage#initialize
        def initialize(*args)
          textdomain "autoinst"
          super
        end

        # @macro seeCustomWidget
        def contents
          VBox(
            Left(raid_name_widget),
            Left(md_level_widget),
            Left(parity_algorithm_widget),
            Left(chunk_size_widget),
            VStretch()
          )
        end

        # @macro seeAbstractWidget
        def init
          raid_name_widget.value = drive.device
          raid_options = drive.raid_options
          if raid_options
            md_level_widget.value = raid_options.raid_type.to_s
            parity_algorithm_widget.value = raid_options.parity_algorithm
            chunk_size_widget.value = raid_options.chunk_size
          end
        end

        # Returns the widgets values
        #
        # @return [Hash<String,Object>]
        def values
          {
            "device"       => raid_name_widget.value,
            "raid_options" => {
              "raid_type"        => md_level_widget.value,
              "parity_algorithm" => parity_algorithm_widget.value,
              "chunk_size"       => chunk_size_widget.value
            }
          }
        end

      private

        # RAID name input field
        #
        # @return [RaidName]
        def raid_name_widget
          @raid_name_widget ||= RaidName.new
        end

        # RAID level widget
        #
        # @return [MdLevel]
        def md_level_widget
          @md_level_widget ||= MdLevel.new
        end

        # Parity algorithm
        #
        # @return [ParityAlgorithm]
        def parity_algorithm_widget
          @parity_algorithm_widget ||= ParityAlgorithm.new
        end

        # Chunk size
        #
        # @return [ChunkSize]
        def chunk_size_widget
          @chunk_size_widget ||= ChunkSize.new
        end
      end
    end
  end
end
