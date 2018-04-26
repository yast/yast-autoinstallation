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


require "autoinstall/autoinst_issues/issue"

module Y2Autoinstallation
  module AutoinstIssues
    # Represents an AutoYaST situation where a mandatory value is missing.
    #
    # @example Missing value for attribute 'product' in 'software' section.
    #   problem = MissingValue.new("software","product")
    class MissingValue < Issue
      # @return [String] Name of the missing attribute
      attr_reader :attr

      # @param section [String] Section where it was detected
      # @param attr    [String] Name of the missing attribute
      def initialize(section, attr)
        textdomain "autoinst"

        @section = section
        @attr = attr
      end

      # Fatal problem
      #
      # @return [Symbol] :fatal
      # @see Issue#severity
      def severity
        :fatal
      end

      # Return the error message to be displayed
      #
      # @return [String] Error message
      # @see Issue#message
      def message
        # TRANSLATORS: AutoYaST element
        _("Missing element '%{attr}'") % { attr: @attr }
      end
    end
  end
end
