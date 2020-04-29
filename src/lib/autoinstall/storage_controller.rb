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
  # Controller for the editing the partitioning section of a profile
  #
  # It is supposed to be used internally by
  # {Y2Autoinstallation::Dialogs::Storage}.
  class StorageController
    # @return [Y2Storage::AutoinstProfile::PartitioningSection]
    #   Partition section
    attr_reader :partitioning

    # Constructor
    #
    # @param partitioning [Y2Storage::AutoinstProfile::PartitioningSection]
    #   Partitioning section of the profile
    def initialize(partitioning)
      @partitioning = partitioning
      @modified = false
    end

    TYPES_MAP = {
      disk: :CT_DISK,
      raid: :CT_RAID,
      lvm:  :CT_LVM
    }.freeze

    # Adds a new drive section of the given type
    #
    # @param type [Symbol]
    def add_drive(type)
      section = Y2Storage::AutoinstProfile::DriveSection.new_from_hashes(type: TYPES_MAP[type])
      partitioning.drives << section
    end

    # Adds a new partition section under the given section
    #
    # @param parent [Y2Storage::AutoinstProfile::DriveSection] Parent section
    def add_partition(parent)
      parent.partitions << Y2Storage::AutoinstProfile::PartitionSection.new(parent)
    end

    # Updates a drive section
    # @param section [Y2Storage::AutoinstProfile::PartitionSection] Partition section
    # @param values [Hash] Values to update
    def update_drive(section, values)
      partitions = section.partitions
      section.init_from_hashes(values.merge("type" => section.type))
      section.partitions = partitions
    end

    # Updates a partition section
    #
    # @param section [Y2Storage::AutoinstProfile::PartitionSection] Partition section
    # @param values [Hash] Values to update
    def update_partition(section, values)
      clean_section(section)
      section.init_from_hashes(values)
    end

    # Determines the partition usage
    #
    # NOTE: perhaps this logic should live in the PartitionSection class.
    #
    # @param section [Y2Storage::AutoinstProfile::PartitionSection] Partition section
    # @return [Symbol]
    def partition_usage(section)
      use =
        if section.mount
          :filesystem
        elsif section.raid_name
          :raid
        elsif section.lvm_group
          :lvm_pv
        end
      use || :filesystem
    end

    # Returns a collection of LVM devices based on LVM group names
    #
    # @return [Array<String>]
    def lvm_devices
      drives(type: :lvm).map { |d| d.device.delete_prefix("/dev/") }
    end

    # It determines whether the profile was modified
    #
    # @todo Implement logic to detect whether the partitioning
    #   was modified or not.
    def modified?
      true
    end

  private

    # Cleans a profile section
    #
    # Resets all known attributes
    # @param section [Y2Storage::AutoinstProfile::SectionWithAttributes]
    def clean_section(section)
      section.class.attributes.each do |attr|
        section.public_send("#{attr[:name]}=", nil)
      end
    end

    # Returns drive sections
    #
    # @param type [Symbol] an specific drive type, such as :lvm, :disk, :raid
    # @return [Array<Y2Storage::AutoinstProfile::DriveSection>] drive sections
    def drives(type: nil)
      return partitioning.drives unless type

      partitioning.drives.select { |d| d.type == TYPES_MAP[type] }
    end
  end
end
