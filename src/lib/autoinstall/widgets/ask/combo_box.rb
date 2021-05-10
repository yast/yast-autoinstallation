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

require "yast"
require "cwm"
require "autoinstall/widgets/ask/field"

module Y2Autoinstall
  module Widgets
    module Ask
      # Combo Box widget for <ask> questions
      #
      # @see Dialog
      class ComboBox < CWM::ComboBox
        include Field

        # @param question [Y2Autoinstall::Ask::Question] Question to represent
        def initialize(question)
          @question = question
        end

        # @macro seeAbstractWidget
        def opt
          [:notify, :immediate]
        end

        # @macro seeComboBox
        def items
          @question.options.map do |option|
            label = option.label || option.value
            [option.value, label]
          end
        end
      end
    end
  end
end
