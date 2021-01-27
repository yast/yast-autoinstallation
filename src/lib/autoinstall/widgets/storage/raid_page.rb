# Copyright (c) [2020-2021] SUSE LLC
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
require "autoinstall/widgets/storage/disklabel"

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

        # @see DrivePage#widgets
        def widgets
          [
            HSquash(raid_name_widget),
            md_level_widget,
            parity_algorithm_widget,
            chunk_size_widget,
            disklabel_widget
          ]
        end

        # @see DrivePage#init_widgets_values
        def init_widgets_values
          raid_name_widget.value = drive.device
          raid_options = drive.raid_options
          disklabel_widget.value = drive.disklabel
          if raid_options
            md_level_widget.value = raid_options.raid_type.to_s
            parity_algorithm_widget.value = raid_options.parity_algorithm
            chunk_size_widget.value = raid_options.chunk_size
          end
        end

        # @see DrivePage#widgets_values
        def widgets_values
          {
            "device"       => raid_name_widget.value,
            "disklabel"    => disklabel_widget.value,
            "raid_options" => {
              "raid_type"        => md_level_widget.value,
              "parity_algorithm" => parity_algorithm_widget.value,
              "chunk_size"       => chunk_size_widget.value
            }
          }
        end

      private

        # Widget for setting the RAID name
        def raid_name_widget
          @raid_name_widget ||= RaidName.new
        end

        # Widget for choosing the RAID level
        def md_level_widget
          @md_level_widget ||= MdLevel.new
        end

        # Widget for choosing the RAID Parity algorithm
        def parity_algorithm_widget
          @parity_algorithm_widget ||= ParityAlgorithm.new
        end

        # Widget for setting the chunk size
        def chunk_size_widget
          @chunk_size_widget ||= ChunkSize.new
        end

        # Widget for setting the type of the RAID partition table
        def disklabel_widget
          @disklabel_widget ||= Disklabel.new
        end
      end
    end
  end
end
