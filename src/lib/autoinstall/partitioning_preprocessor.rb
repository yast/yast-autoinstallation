# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

require "y2storage"
require "autoinstall/dialogs/disk_selector"

module Y2Autoinstallation
  # This class is responsible for preprocessing the +<partitioning/>+ section
  # of an AutoYaST profile.
  #
  # At this time, the only preprocessing is replacing +device=ask+ with a real
  # device name.
  class PartitioningPreprocessor
    include Yast

    # Preprocesses the partitioning section
    #
    # It returns a new object so the original section is not modified.
    #
    # @param drives [Array<Hash>] List of drives according to an AutoYaST
    #   +partitioning+ section.
    def run(drives)
      return if drives.nil?

      replace_ask(deep_copy(drives))
    end

  protected

    # Replaces +ask+ for user selected values
    #
    # When +device+ is set to +ask+, ask the user about which device to use.
    #
    # @param drives [Array<Hash>] Drives definition from an AutoYaST profile
    # @return [Array<Hash>] Drives definition replacing +ask+ for user selected values
    def replace_ask(drives)
      blacklist = []
      drives.each_with_index do |drive, idx|
        next unless drive["device"] == "ask"

        selection = select_disk(idx, blacklist)
        return nil if selection == :abort

        drive["device"] = selection
        blacklist << drive["device"]
      end
    end

    # Asks the user about which device should be used
    #
    # @param blacklist [Array<String>] List of device names that were already used
    # @return [String,Symbol] Selected device name
    def select_disk(drive_index, blacklist)
      Y2Autoinstallation::Dialogs::DiskSelector.new(
        drive_index: drive_index, blacklist: blacklist
      ).run
    end
  end
end
