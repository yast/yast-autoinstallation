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
require "y2storage"

module Y2Autoinstallation
  module Presenters
    # Object-oriented representation of the type field of a <drive> section
    class DriveType
      include Yast::I18n
      extend Yast::I18n

      # Constructor
      #
      # @param id [Symbol] raw value of the field, like :CT_DISK, CT_LVM, etc.
      # @param label [String]
      def initialize(id, label)
        textdomain "autoinst"

        @symbol = id
        @label = label
      end

      # DriveType for CT_DISK
      DISK = new(:CT_DISK, N_("Disk")).freeze
      # DriveType for CT_LVM
      LVM = new(:CT_LVM, N_("LVM")).freeze
      # DriveType for CT_RAID
      RAID = new(:CT_RAID, N_("RAID")).freeze

      # All drive types
      ALL = [DISK, RAID, LVM].freeze

      # All possible types
      #
      # @return [Array<DriveType>]
      def self.all
        ALL.dup
      end

      # Type corresponding to the given raw value of the field
      #
      # @param id [#to_sym]
      def self.find(id)
        all.find { |type| type.to_sym == id.to_sym }
      end

      # Localized name of the type
      #
      # @return [String]
      def label
        _(@label)
      end

      # Raw value of the type in the section, like :CT_DISK
      #
      # @return [Symbol]
      def to_sym
        @symbol
      end

      # String representation of the type, like DISK
      #
      # @return [String]
      def to_s
        to_sym.to_s.delete_prefix("CT_")
      end
    end
  end
end
