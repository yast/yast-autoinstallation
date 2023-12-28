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

Yast.import "Popup"

module Y2Autoinstall
  module Widgets
    module Ask
      # Password field widget for <ask> questions
      #
      # @see Dialog
      class PasswordField < CWM::CustomWidget
        include Field

        # @param question [Y2Autoinstall::Ask::Question] Question to represent
        def initialize(question)
          super()
          textdomain "autoinst"
          @question = question
        end

        # Sets the password value
        #
        # This method updates both password widgets
        #
        # @return [String]
        def value=(val)
          new_value = val.to_s
          Yast::UI.ChangeWidget(Id(widget_id), :Value, new_value)
          Yast::UI.ChangeWidget(Id(confirmation_widget_id), :Value, new_value)
        end

        # Returns the password value
        #
        # @return [String]
        def value
          Yast::UI.QueryWidget(Id(widget_id), :Value)
        end

        # @macro seeAbstractWidget
        # The ':notify' option is needed to notify the timer when the value changes.
        # @see Y2Autoinstall::Widgets::Ask::Dialog::TimeoutWrapper
        def opt
          [:hstretch, :notify]
        end

        def contents
          VBox(
            Password(Id(widget_id), Opt(*opt), label),
            Password(Id(confirmation_widget_id), Opt(*opt), "")
          )
        end

        # @macro seeCustomWidget
        def validate
          return true if value == confirmation_value

          Yast::Popup.Message(
            format(_("%{field}: the passwords do not match."), field: label)
          )
          Yast::UI.SetFocus(Id(widget_id))
          false
        end

      private

        def confirmation_widget_id
          "#{widget_id}_confirmation"
        end

        def confirmation_value
          Yast::UI.QueryWidget(Id(confirmation_widget_id), :Value)
        end
      end
    end
  end
end
