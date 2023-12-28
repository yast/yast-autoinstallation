# Copyright (c) [2017] SUSE LLC
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

require "ui/dialog"

Yast.import "Label"
Yast.import "UI"

module Y2Autoinstallation
  module Dialogs
    # Generic dialog for AutoYaST questions supporting RichText.
    #
    # It can behave in two different ways:
    #
    # * Ask the user if she/he wants to continue or abort the installation.
    # * Display a message and only offer an 'Abort' button.
    #
    # In order to integrate nicely with AutoYaST, a timeout can be set.
    # Bear in mind that the timeout will not be respected when showing only
    # the 'Abort' button.
    #
    # This dialog could be extended in the future in order to support other
    # AutoYaST interaction which are not covered in the Yast::Report module.
    class Question < UI::Dialog
      # @return [String] Dialog's content
      attr_reader :content

      # Constructor
      #
      # @param headline    [String]  Dialog's headline
      # @param content     [String]  Dialog's content
      # @param timeout     [Integer] Countdown (in seconds); 0 means no timeout.
      # @param buttons_set [Symbol]  Buttons set (:abort, :question)
      def initialize(headline, content, timeout: 10, buttons_set: :question)
        super()
        @headline = headline
        @content = content
        @remaining_time = timeout
        @timed = timeout > 0
        @buttons_set = buttons_set
      end

      # Return YaST terms for dialog's content
      #
      # @return [Yast::Term] Dialog's content
      # @see UI::Dialog#dialog_content
      def dialog_content
        HBox(
          VSpacing(20),
          VBox(
            HSpacing(70),
            Left(Heading(@headline)),
            VSpacing(1),
            RichText(content),
            timed? ? ReplacePoint(Id(:counter_replace), counter) : Empty(),
            ButtonBox(*buttons)
          )
        )
      end

      # 'Continue' button handler
      #
      # When the 'Continue' button is pressed, the dialog will return the :ok value.
      def ok_handler
        finish_dialog(:ok)
      end

      # 'Abort' button handler
      #
      # When the 'Abort' button is pressed, the dialog will return the :abort value.
      def abort_handler
        finish_dialog(:abort)
      end

      # 'Stop' button handler
      #
      # When the 'Stop' button is pressed, the countdown will stop.
      def stop_handler
        @remaining_time = nil
        Yast::UI.ChangeWidget(Id(:stop), :Enabled, false)
      end

      def timeout_handler
        return finish_dialog(:ok) if @remaining_time.zero?

        @remaining_time -= 1
        Yast::UI.ReplaceWidget(Id(:counter_replace), counter)
      end

    private

      # @return [Integer] Timeout
      attr_reader :timeout

      # @return [Symbol] Buttons set (:abort, :question)
      attr_reader :buttons_set

      # Determine whether it is a timed dialog or not
      #
      # @return [Boolean] True if the timeout is running; false otherwise
      def timed?
        @timed
      end

      # Return dialog buttons
      #
      # @see question_buttons
      # @see abort_buttons
      def buttons
        send("#{buttons_set}_buttons")
      end

      # Return buttons to show when the user should be asked about what to do
      #
      # @return [Array<Yast::Term>]
      def question_buttons
        set = [
          PushButton(Id(:ok), Opt(:okButton, :key_F10, :default), Yast::Label.ContinueButton),
          abort_button
        ]

        if timed?
          set.unshift(
            PushButton(Id(:stop), Opt(:customButton), Yast::Label.StopButton)
          )
        end

        set
      end

      # Return buttons to show when abort is the only option
      #
      # @return [Array<Yast::Term>]
      def abort_buttons
        [abort_button]
      end

      # Return an 'Abort' button
      #
      # @return Yast::Term
      def abort_button
        PushButton(Id(:abort), Opt(:cancel_button, :key_F9), Yast::Label.AbortButton)
      end

      # Timeout counter
      #
      # @return [Yast::Term]
      def counter
        Label(Id(:counter), @remaining_time.to_s)
      end

      # Handle user input
      #
      # @return [Symbol] User input (:ok, :stop, :abort or :timeout)
      def user_input
        if timed? && @remaining_time
          Yast::UI.TimeoutUserInput(1000)
        else
          Yast::UI.UserInput
        end
      end
    end
  end
end
