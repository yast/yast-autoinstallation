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

Yast.import "AutoinstStorage"
Yast.import "Profile"

module Y2Autoinstallation
  # Activation callbacks for Y2Storage.
  class ActivateCallbacks < Y2Storage::Callbacks::Activate
    # Determines whether multipath should be enabled
    #
    # This hook returns true if start_multipath was set to +true+.
    #
    # @return [Boolean]
    def multipath(_looks_like_real_multipath)
      Yast::AutoinstStorage.general_settings.fetch("start_multipath", false)
    end

    # Determines whether LUKS should be activated
    #
    # At this point, AutoYaST has not parsed the 'partitioning' section from
    # the profile, so it does not know which crypted devices are going to be
    # reused. The best option is to check the raw profile (from
    # {Yast::ProfileClass#current}) and try to unlock devices using all present
    # keys for reused devices
    #
    # @param uuid    [String]  UUID
    # @param attempt [Integer] Attempt number
    # @return [Storage::PairBoolString]
    # @see Storage::ActivateCallbacks
    def luks(uuid, attempt)
      key = crypt_keys_from_profile[attempt - 1]
      if key.nil?
        log.warn "Could not decrypt device '#{uuid}'"
        return Storage::PairBoolString.new(false, "")
      end
      Storage::PairBoolString.new(true, key)
    end

  protected

    # Retrieves crypt keys for reused devices from the profile
    #
    # All encryption keys are considered, no matter if they are associated to
    # a device that should be reused or not. The reason is that it might happen that a user
    # wants to reuse a logical volume but forgets setting 'create' to 'false' for the
    # volume group.
    #
    # @return [Array<String>] List of crypt keys
    def crypt_keys_from_profile
      profile = Yast::Profile.current.fetch("partitioning", [])
      devices = profile.map { |d| d.fetch("partitions", []) }.flatten
      keys = devices.map { |p| p["crypt_key"] }
      keys.compact.uniq.sort
    end
  end
end
