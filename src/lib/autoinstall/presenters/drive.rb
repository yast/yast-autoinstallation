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
require "autoinstall/presenters/section"
require "autoinstall/presenters/drive_type"
require "autoinstall/presenters/partition"

module Y2Autoinstallation
  module Presenters
    # Presenter for Y2Storage::AutoinstProfile::DriveSection
    class Drive < Section
      # Constructor
      #
      # @see Section#initialize
      def initialize(section)
        textdomain "autoinst"
        super
        @partitions = section.partitions.map { |part| Partition.new(part, self) }
      end

      # Presenters for the partition sections within this drive section
      #
      # @return [Array<Partition>]
      attr_reader :partitions

      # @return [DriveType]
      def type
        @type ||= DriveType.find(section.type) || DriveType::DISK
      end

      # Updates a drive section
      #
      # @param values [Hash] Values to update
      def update(values)
        partitions = section.partitions
        super(values.merge("type" => section.type))
        section.partitions = partitions
      end

      # Localized label to represent this section in the UI
      #
      # @return [String]
      def ui_label
        if device && !device.empty?
          # TRANSLATORS: 'Drive' is the name of a section of the AutoYaST profile, translating
          # the term is likely a bad idea.
          # %{type} and %{name} are placeholders, do not translate them.
          format(_("Drive (%{type}): %{name}"), type: type.label, name: section.device)
        else
          # TRANSLATORS: 'Drive' is the name of a section of the AutoYaST profile, translating
          # the term is likely a bad idea. %s is substituted by the type of drive.
          format(_("Drive (%s)"), type.label)
        end
      end
    end
  end
end
