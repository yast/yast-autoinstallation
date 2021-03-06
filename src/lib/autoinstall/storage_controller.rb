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
require "autoinstall/presenters"
require "y2storage/autoinst_profile/drive_section"
require "y2storage/autoinst_profile/partition_section"

module Y2Autoinstallation
  # Controller for editing the <partitioning> section of a profile
  #
  # It is intended to be used internally by {Dialogs::Storage}.
  class StorageController
    # Partitioning section that is being edited
    #
    # @return [Y2Storage::AutoinstProfile::PartitioningSection]
    attr_reader :partitioning

    # Sub-section of {#partitioning} that is currently selected to be modified
    #
    # @return [Y2Storage::AutoinstProfile::SectionWithAttributes, nil]
    attr_accessor :section

    # Constructor
    #
    # @param partitioning [Y2Storage::AutoinstProfile::PartitioningSection]
    #   Partitioning section of the profile
    def initialize(partitioning)
      @partitioning = partitioning
      @section = partitioning.drives.first
      @modified = false
    end

    # Adds a new drive section of the given type
    #
    # @param type [Presenters::DriveType]
    def add_drive(type)
      self.section = Y2Storage::AutoinstProfile::DriveSection.new_from_hashes(
        { type: type.to_sym },
        partitioning
      )
      partitioning.drives << section
    end

    # Adds a new partition section to the current drive section
    def add_partition
      return unless drive

      drive.partitions << Y2Storage::AutoinstProfile::PartitionSection.new(drive)
      self.section = drive.partitions.last
    end

    # Removes currently selected section
    def delete_section
      return unless section

      if section.is_a?(Y2Storage::AutoinstProfile::DriveSection)
        drives.delete(section)
        self.section = drives.first
      else
        section.parent.partitions.delete(section)
        self.section = section.parent
      end
    end

    # It determines whether the profile was modified
    #
    # @todo Implement logic to detect whether the partitioning
    #   was modified or not.
    def modified?
      true
    end

    # Presenters for all the drive sections
    #
    # @return [Array<Presenters::Drive>]
    def drive_presenters
      drives.map { |d| Presenters::Drive.new(d) }
    end

    # Drive sections inside the partitioning one
    #
    # @return [Array<Y2Storage::AutoinstProfile::DriveSection>]
    def drives
      partitioning.drives
    end

  private

    # Drive section that is currently selected directly or indirectly (ie.
    # because one of its partition sections is selected)
    #
    # @return [Y2Storage::AutoinstProfile::DriveSection]
    def drive
      return nil unless section

      section.is_a?(Y2Storage::AutoinstProfile::PartitionSection) ? section.parent : section
    end
  end
end
