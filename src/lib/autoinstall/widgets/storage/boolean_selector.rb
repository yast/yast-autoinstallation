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
require "cwm/common_widgets"

module Y2Autoinstallation
  module Widgets
    module Storage
      # A base widget for building selectors to manage boolean options.
      # It could include an empty option meaning "use the default".
      class BooleanSelector < CWM::ComboBox
        # Constructor
        def initialize
          textdomain "autoinst"
          super
        end

        # @macro seeAbstractWidget
        def label
          ""
        end

        # @macro seeComboBox
        def items
          [
            empty_item,
            ["true", _("Yes")],
            ["false", _("No")]
          ].compact
        end

        # @macro seeAbstractWidget
        def value
          result = super

          if result.to_s.empty?
            nil
          else
            result == "true"
          end
        end

        # @macro seeAbstractWidget
        def value=(val)
          super(val.to_s)
        end

        # Whether the selector may include an empty option
        #
        # @return [Boolean] true if the empty option must be included; false otherwise
        def include_blank?
          true
        end

      private

        # The empty option
        #
        # @return [Array(String, String), nil]
        def empty_item
          return nil unless include_blank?

          ["", ""]
        end
      end
    end
  end
end
