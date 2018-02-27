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

Yast.import "AutoinstStorage"

module Y2Autoinstallation
  # Activate callbacks for Y2Storage.
  class ActivateCallbacks < Y2Storage::Callbacks::Activate
    # Determine whether multipath should be enabled
    #
    # This hook returns true if start_multipath was set to +true+.
    #
    # @return [Boolean]
    def multipath
      Yast::AutoinstStorage.general_settings.fetch("start_multipath", false)
    end

    # Determine whether LUKS should be activated
    #
    # For AutoYaST, LUKS is not activated.
    #
    # @param _uuid    [String]  UUID
    # @param _attempt [Integer] Attempt number
    # @return [Storage::PairBoolString]
    # @see Storage::ActivateCallbacks
    def luks(_uuid, _attempt)
      Storage::PairBoolString.new(false, "")
    end
  end
end
