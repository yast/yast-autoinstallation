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
require "autoinstall/autoinst_profile/ask_selection_entry"

module Y2Autoinstall
  module AutoinstProfile
    # Represents a <ask> element from an <ask-list>
    #
    #   <ask>
    #     <question>Username</question>
    #     <default>linux</default>
    #     <type>string</type>
    #     <title>New User</title>
    #     <pathlist t="list">
    #       <path>users,1,username</path>
    #     </pathlist>
    #     <stage>initial</stage>
    #     <dialog t="integer">1</dialog>
    #     <element t="integer">1</element>
    #  </ask>
    class AskSection < ::Installation::AutoinstProfile::SectionWithAttributes
      def self.attributes
        [
          { name: :question },
          { name: :default },
          { name: :help },
          { name: :title },
          { name: :type },
          { name: :password },
          { name: :pathlist },
          { name: :path },
          { name: :file },
          { name: :stage },
          { name: :selection },
          { name: :dialog },
          { name: :element },
          { name: :width },
          { name: :height },
          { name: :frametitle },
          { name: :script },
          { name: :ok_label },
          { name: :back_label },
          { name: :timeout },
          { name: :default_value_script }
        ]
      end

      define_attr_accessors

      # @!attribute question
      #   @return [String,nil] Question text

      # @!attribute default
      #   @return [Object,nil] Default value for the question

      # @!attribute help
      #   @return [String,nil] Help text

      # @!attribute title
      #   @return [String,nil] A title to be shown above the questions

      # @!attribute type
      #   @return [String,nil] Question type ('symbol', 'boolean', 'string', 'integer'
      #     or 'static_text')

      # @!attribute password
      #   @return [Boolean,nil] When set to `true`, it is supposed to be a password

      # @!attribute pathlist
      #   @return [Array<String>,nil] Path of an element in the profile

      # @!attribute file
      #   @return [String,nil] Path to a file to store the answer to the question

      # @!attribute stage
      #   @return [String,nil] Which stage should the question be presented ('initial' for
      #   1st stage or 'cont' for the 2nd one).

      # @!attribute selection
      #   @return [Array<AskSelectionEntry>,nil] List of possible values to choose as answer

      # @!attribute dialog
      #   @return [Integer,nil] Dialog number to place the question

      # @!attribute element
      #   @return [Integer,nil] Question order when there are more than one in the same dialog

      # @!attribute width
      #   @return [Integer,nil] Dialog width

      # @!attribute height
      #   @return [Integer,nil] Dialog height

      # @!attribute frametitle
      #   @return [String,nil] Frame title

      # @!attribute script
      #   @return [String,nil] Script to run after the question is answered

      # @!attribute ok_label
      #   @return [String,nil] Label for the `Ok` button

      # @!attribute back_label
      #   @return [String,nil] Label for the `Back` button

      # @!attribute timeout
      #   @return [Integer,nil] Timeout

      # @!attribute default_value_script
      #   @return [AskScript] Script to get the default value for the question

      def initialize(parent = nil)
        super
        @pathlist = []
        @selection = []
      end

      # Method used by {.new_from_hashes} to populate the attributes.
      #
      # @param hash [Hash] see {.new_from_hashes}
      def init_from_hashes(hash)
        super
        @pathlist = hash["pathlist"]
        @selection = hash["selection"]&.map { |e| AskSelectionEntry.new_from_hashes(e) }
      end
    end
  end
end
