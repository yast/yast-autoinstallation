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
        :options, :element_id, :frametitle, :script, :default_value_script
      attr_reader :stage, :value

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
      #   @return [Array<String>] Path of an element in the profile

      # @!attribute file
      #   @return [String,nil] Path to a file to store the answer to the question

      # @!attribute stage
      #   @return [Symbol] Which stage should the question be presented (:initial for
      #   1st stage or :cont for the 2nd one).

      # @!attribute options
      #   @return [Array<QuestionOption>] List of possible values to choose as answer

      # @!attribute element_id
      #   @return [Integer,nil] Question order when there are more than one in the same dialog

      # @!attribute frametitle
      #   @return [String,nil] Frame title

      # @!attribute script
      #   @return [AskScript,nil] Script to run after the question is answered

      # @!attribute default_value_script
      #   @return [AskScript,nil] Script to get the default value for the question

      # @!attribute value
      #   @return [Object,nil] Question value (usually from user)

      # @param text       [String] Question text
      # @param element_id [Integer,nil] Question order within its corresponding dialog
      def initialize(text, element_id = nil)
        @text = text
        @element_id = element_id
        @stage = :initial
        @options = []
        @paths = []
      end

      # Sets the stage for the question
      #
      # @param new_stage [Symbol] :initial or :cont
      def stage=(new_stage)
        @stage = new_stage.to_sym if new_stage
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
