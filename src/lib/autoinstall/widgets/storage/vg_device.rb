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
      # Widget to select the physical volume for a volume group
      #
      # It corresponds to the `device` element in the profile.
      class VgDevice < CWM::InputField
        def initialize
          textdomain "autoinst"
          super
        end

        # @macro seeAbstractWidget
        def label
          _("Device")
        end

        def value
          prefix(super)
        end

        def value=(device)
          super(prefix(device))
        end

      private

        # Ensure that device starts with /dev/
        #
        # @param device [String, nil] device name to check
        # @return [String] the device name properly prefixed
        def prefix(device)
          return "" if blank?(device)

          device.start_with?("/dev/") ? device : "/dev/#{device}"
        end

        # Checks whether the given value is blank
        #
        # @param val [String, nil] value to check
        # @return [Boolean]
        def blank?(val)
          val.nil? || val.empty?
        end
      end
    end
  end
end
