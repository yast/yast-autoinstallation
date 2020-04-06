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
require "cwm/common_widgets"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Widget to select a block device for a partition section
      class DiskDevice < CWM::ComboBox
        # Constructor
        #
        # @param initial [String,nil] Initial value
        def initialize(initial: nil)
          textdomain "autoinst"
          @initial = initial
        end

        # @macro seeAbstractWidget
        def init
          self.value = initial if initial
        end

        # @macro seeAbstractWidget
        def label
          _("Device")
        end

        # @macro seeAbstractWidget
        def opt
          [:editable, :hstretch]
        end

        DISKS = [
          "/dev/sda", "/dev/sdb", "/dev/vda", "/dev/vdb", "/dev/hda", "/dev/hdb"
        ].freeze
        private_constant :DISKS

        # Returns the list of possible values
        #
        # @return [Array<Array<String, String>>] List of possible values
        def items
          return @items if @items

          known_disks = DISKS.dup
          known_disks.unshift(initial) if initial && !known_disks.include?(initial)
          @items = [["", "auto"]] + known_disks.map { |i| [i, i] }
        end

      private

        # @return [String,nil] Initial value
        attr_reader :initial
      end
    end
  end
end
