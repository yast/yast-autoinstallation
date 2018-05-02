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
    # Represents an AutoYaST situation where a mandatory value is missing.
    #
    # @example Missing value for attribute 'bar' in 'foo' section.
    #   problem = MissingValue.new("foo","bar")
    class MissingValue < Issue
      # @return [String] Name of the missing attribute
      attr_reader :attr

      # @param section     [String] Section where it was detected
      # @param attr        [String] Name of the missing attribute
      # @param description [String] additional explanation; optional
      # @param severity    [Symbol] :warn, :fatal = abort the installation ; optional
      def initialize(section, attr, description = "", severity = :warn)
        textdomain "autoinst"

        @section = section
        @attr = attr
        @description = description
        @severity = severity
      end

      # Fatal problem
      #
      # @return [Symbol] :fatal, :warn
      # @see Issue#severity
      def severity
        @severity
      end

      # Return the error message to be displayed
      #
      # @return [String] Error message
      # @see Issue#message
      def message
        # TRANSLATORS:
        # 'attr' is an AutoYaST element
        # 'description' has already been translated in other modules.
        _("Missing element '%{attr}'. %{description}") %
          { attr: @attr, description: @description }
      end
    end
  end
end
