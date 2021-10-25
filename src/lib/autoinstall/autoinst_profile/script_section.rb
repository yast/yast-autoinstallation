# Copyright (c) [2021] SUSE LLC
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

require "installation/autoinst_profile/section_with_attributes"

module Y2Autoinstall
  module AutoinstProfile
    # Represents <script> section
    #
    # It can be used to represent any script from a profile, although there might
    # be small differences between them. See `scripts.rnc` for further information.
    class ScriptSection < ::Installation::AutoinstProfile::SectionWithAttributes
      def self.attributes
        [
          { name: :chrooted },
          { name: :environment },
          { name: :filename },
          { name: :interpreter },
          { name: :location },
          { name: :source },
          { name: :debug },
          { name: :feedback },
          { name: :feedback_type },
          { name: :rerun },
          { name: :rerun_on_error },
          { name: :notification },
          { name: :param_list, xml_name: "param-list" }
        ]
      end

      define_attr_accessors

      # @!attribute chrooted
      #   @return [Boolean,nil] Whether the script should run in a chrooted environment

      # @!attribute filename
      #   @return [String,nil] Script filename

      # @!attribute interpreter
      #   @return [String,nil] Script interpreter

      # @!attribute location
      #   @return [String,nil] Script location (usually a URL)

      # @!attribute source
      #   @return [String,nil] Script source code

      # @!attribute debug
      #   @return [Boolean,nil] Log the script

      # @!attribute feedback
      #   @return [Boolean,nil] Display output and error messages

      # @!attribute feedback_type
      #   @return [String,nil] Set the feedback type (message, warning, or error)

      # @!attribute notification
      #   @return [Boolean,nil] Message to show while the script is running

      # @!attribute param_list
      #   @return [Array<String>,nil] Parameters list
    end
  end
end
