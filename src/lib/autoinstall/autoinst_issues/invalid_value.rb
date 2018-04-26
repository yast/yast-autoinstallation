# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
    # Represents an AutoYaST situation where an invalid value was given.
    #
    class InvalidValue < Issue
      include Yast::Logger

      # @param section     [String] main section name in the AutoYaST configuration file
      # @param attribute   [String] wrong attribute
      # @param value       [String] wrong attribute value
      # @param description [String] additional explanation
      # @param severity    [Symbol] :warn, :fatal = abort the installation
      def initialize(section, attribute, value, description, severity = :warn)
        textdomain "autoinst"
        @section = section
        @attribute = attribute
        @value = value
        @description = description
        @severity = severity
      end

      # Return problem severity
      #
      # @return [Symbol] :warn, :fatal
      def severity
        @severity
      end

      # Return the error message to be displayed
      #
      # @return [String] Error message
      # @see Issue#message
      def message
        # TRANSLATORS:
        # 'value' is a generic value (number or string) 'attr' is an AutoYaST element
        # 'description' has already been translated in other modules.
        _("Invalid value '%{value}' for attribute '%{attribute}': %{description}") %
          { value: @value, attribute: @attribute, description: @description }
      end
    end
  end
end
