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
    class Dialog
      attr_reader :id
      attr_accessor :title, :height, :width, :timeout, :ok_label,
        :back_label, :questions

      # @!attribute id
      #   @return [Integer,nil] Dialog number to place the question

      # @!attribute title
      #   @return [String,nil] A title to be shown above the questions

      # @!attribute width
      #   @return [Integer,nil] Dialog width

      # @!attribute height
      #   @return [Integer,nil] Dialog height

      # @!attribute ok_label
      #   @return [String,nil] Label for the `Ok` button

      # @!attribute back_label
      #   @return [String,nil] Label for the `Back` button

      # @!attribute timeout
      #   @return [Integer,nil] Timeout

      # @param id [Integer,nil] Dialog identifier
      # @param questions [Array<Question>] Questions included in the dialog
      def initialize(id, questions = [])
        @id = id
        @questions = questions
      end
    end
  end
end
