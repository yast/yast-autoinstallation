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
      # CheckBox widget for <ask> questions
      #
      # @see Dialog
      class CheckBox < CWM::CheckBox
        include Field

        # @param question [Y2Autoinstall::Ask::Question] Question to represent
        def initialize(question)
          super()
          textdomain "autoinst"
          @question = question
        end

        # @macro seeAbstractWidget
        # The ':notify' option is needed to notify the timer when the value changes.
        # @see Y2Autoinstall::Widgets::Ask::Dialog::TimeoutWrapper
        def opt
          [:notify]
        end

        # @macro seeAbstractWidget
        def init
          if !@question.value.nil?
            self.value = @question.value
            return
          end

          if @question.default_value_script
            default_from_script = run_script(@question.default_value_script)
          end

          self.value = if default_from_script.nil?
            @question.default == "true"
          else
            default_from_script == "true"
          end
        end
      end
    end
  end
end
