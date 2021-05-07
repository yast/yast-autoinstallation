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

module Y2Autoinstall
  module Ask
    # Represents a question related to an <ask> element
    class Question
      attr_accessor :text, :default, :help, :type, :password, :paths, :file,
        :options, :frametitle, :script, :default_value_script
      attr_reader :value

      # @!attribute text
      #   @return [String] Question text

      # @!attribute default
      #   @return [Object,nil] Default value for the question

      # @!attribute help
      #   @return [String,nil] Help text

      # @!attribute type
      #   @return [String,nil] Question type ('symbol', 'boolean', 'string', 'integer'
      #     or 'static_text')

      # @!attribute password
      #   @return [Boolean,nil] When set to `true`, it is supposed to be a password

      # @!attribute paths
      #   @return [Array<String>] Paths of elements to update in the profile

      # @!attribute file
      #   @return [String,nil] Path to a file to store the answer to the question.
      #     If nil, the value is not stored.

      # @!attribute options
      #   @return [Array<QuestionOption>] List of possible values to choose as answer. If it
      #     is not empty, it limits the possible answers to the question. It is usually
      #     represented with a ComboBox.

      # @!attribute frametitle
      #   @return [String,nil] Frame title

      # @!attribute script
      #   @return [AskScript,nil] Script to run after the question is answered

      # @!attribute default_value_script
      #   @return [AskScript,nil] Script to get the default value for the question

      # @!attribute value
      #   @return [Object,nil] Question value (usually from user)

      # @param text       [String] Question text
      def initialize(text)
        @text = text
        @options = []
        @paths = []
      end

      # Sets the question answer
      #
      # This method casts the given value to the proper class according to the
      # 'type' attribute.
      #
      # @param val [Object] Question answer
      def value=(val)
        @value = case type
        when "integer"
          val.to_i
        when "boolean"
          [true, "true"].include?(val)
        when "symbol"
          val.to_sym
        else
          val.to_s
        end
      end
    end
  end
end
