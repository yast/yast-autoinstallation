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
      # Selector widget to set the encryption method to use
      class CryptMethod < CWM::ComboBox
        # Constructor
        def initialize
          textdomain "autoinst"
          super
        end

        # @macro seeAbstractWidget
        def label
          _("Encription Method")
        end

        # @macro seeComboBox
        def items
          @items ||= [
            ["", ""],
            *Y2Storage::EncryptionMethod.all.map { |e| [e.to_sym.to_s, e.to_human_string] }
          ]
        end

        # Returns selected encryption method
        #
        # @return [String, nil] selected encryption method; nil if none
        def value
          result = super

          result.to_s.empty? ? nil : result
        end
      end
    end
  end
end