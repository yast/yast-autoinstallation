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
  # Controller for the edition of the partitioning section of a profile
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
    end

    TYPES_MAP = {
      disk: :CT_DISK
    }.freeze

    # Adds a new drive section of the given type
    #
    # @param type [Symbol]
    def add_drive(type)
      section = Y2Storage::AutoinstProfile::DriveSection.new_from_hashes(type: TYPES_MAP[type])
      partitioning.drives << section
      section
    end
  end
end
