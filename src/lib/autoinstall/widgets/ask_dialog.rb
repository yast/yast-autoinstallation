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
require "cwm/popup"

module Y2Autoinstall
  module Widgets
    # Implements a CWM dialog for the {Y2Autoinstall::Ask::Dialog} class
    #
    # The dialog displays all the questions included in the dialog and updates
    # their values accordingly.
    #
    # @example 'Running' a dialog
    #   question = Y2Autoinstall::Ask::Question.new("Username")
    #   dialog = Y2Autoinstall::Ask::Dialog.new(1, [question])
    #   AskDialog.new(dialog).run
    class AskDialog < CWM::Popup
      # Common methods for question widgets
      module AskWidget
        # Returns the widget_id, which is based in the type and the question's object_id
        #
        # @return [String] Widget ID
        def widget_id
          "#{widget_type}_#{@question.object_id}"
        end

        # Returns the widget's label
        #
        # The widget's label corresponds to the question text.
        #
        # @return [String]
        # @macro seeAbstractWidget
        def label
          @question.text
        end

        # Initializes the widget value
        #
        # Use the question's value or the default one.
        # @macro seeAbstractWidget
        def init
          self.value = @question.value || @question.default
        end

        # Stores the widget's value in the question
        #
        # @macro seeAbstractWidget
        def store
          @question.value = value
        end
      end

      # CheckBox widget for a question
      class CheckBox < CWM::CheckBox
        include AskWidget

        # @param question [Y2Autoinstall::Ask::Question] Question to represent
        def initialize(question)
          @question = question
        end

        # @macro seeAbstractWidget
        def opt
          [:notify]
        end

        # @macro seeAbstractWidget
        def init
          checked = @question.value.nil? ? @question.default == "true" : @question.value
          self.value = checked
        end
      end

      class InputField < CWM::InputField
        include AskWidget

        # @param question [Y2Autoinstall::Ask::Question] Question to represent
        def initialize(question)
          @question = question
        end

        # @macro seeAbstractWidget
        def opt
          [:hstretch, :notify, :notifyContextMenu]
        end
      end

      class Password < CWM::InputField
        include AskWidget

        # @param question [Y2Autoinstall::Ask::Question] Question to represent
        def initialize(question)
          @question = question
        end

        # @macro seeAbstractWidget
        def opt
          [:notify, :notifyContextMenu]
        end
      end

      class ComboBox < CWM::ComboBox
        include AskWidget

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

      # Handles the CWM timeout
      #
      # Yast::CWM.show uses a timeout only when some of the widgets has a
      # "ui_timeout". However, it calls Yast::UI.WaitForEvent and there is no
      # feedback while the time is running.
      #
      # This class wraps a set of widgets, adding a counter which is updated
      # after each second.
      class TimeoutWrapper < CWM::CustomWidget
        attr_reader :timeout, :widgets, :remaining

        # @param widgets [Array<AbstractWidget>] Widgets to wrap
        # @param timeout [Integer,nil] Time limit. No time out if is set to 0 or nil.
        def initialize(widgets, timeout: 0)
          @timeout = timeout || 0
          @remaining = @timeout
          @widgets = widgets
          @stopped = false
          self.handle_all_events = true
        end

        # Determines whether the widget is stopped or not
        #
        # @return [Boolean]
        def stopped?
          @stopped
        end

        # Determines whether widget timed out
        #
        # @return [Boolean]
        def timed_out?
          @remaining.zero?
        end

        # Handles CWM events
        #
        # * timeout: updates the counter
        # * stop: stops the counter and ignore any further timeout event
        #
        # @paran event [Hash] CWM event
        def handle(event)
          return if stopped?

          if event["ID"] == :timeout
            decrease_counter
            return :next if timed_out?

          elsif event["ID"] == :stop_counter || event["EventReason"] == "ValueChanged"
            stop
          end

          nil
        end

        def contents
          w = widgets.clone
          w.concat([VStretch(), Label(Id(:counter), timeout.to_s)]) unless timeout.zero?
          VBox(*w)
        end

        def cwm_definition
          timeout.zero? ? super : super.merge("ui_timeout" => 1000)
        end

      private

        # Decreases the time counter
        def decrease_counter
          @remaining -= 1
          Yast::UI.ChangeWidget(Id(:counter), :Label, @remaining.to_s)
        end

        # Stops the counter
        def stop
          @stopped = true
          Yast::UI.ChangeWidget(Id(:stop_counter), :Enabled, false)
        end
      end

      # @macro seeDialog
      attr_reader :disable_buttons

      # Constructor
      #
      # @param dialog [Y2Autoinstall::Ask::Dialog] Dialog specification to display
      # @param disable_back_button [Boolean] Whether the :back button should be disabled
      def initialize(dialog, disable_back_button: false)
        @dialog = dialog
        @disable_buttons = disable_back_button ? ["back_button"] : []
      end

      # @macro seeAbstractWidget
      def title
        dialog.title
      end

      # @macro seeAbstractWidget
      def contents
        widgets = dialog.questions.each_with_index.map { |q| widget_for(q) }
        TimeoutWrapper.new(widgets, timeout: dialog.timeout)
      end

      # @macro seeDialog
      def run
        result = super
        dialog.questions.each { |q| log.debug "#{q.text} -> #{q.value}" }
        result
      end

    private

      attr_reader :dialog

      # Defines the dialog's layout
      #
      # It is redefined because the ButtonBox requires to have buttons with :ok and :cancel
      # roles, and that's not the case in this dialog.
      #
      # @return [Yast::Term]
      def layout
        VBox(
          Id(:WizardDialog),
          HSpacing(50),
          Left(Heading(Id(:title), title || "")),
          VStretch(),
          VSpacing(1),
          MinSize(min_width, min_height, ReplacePoint(Id(:contents), Empty())),
          VSpacing(1),
          VStretch(),
          HBox(*buttons)
        )
      end

      # Returns the minimum width for this dialog
      #
      # @return [Integer]
      def min_width
        dialog.width || super
      end

      # Returns the minimum height for this dialog
      #
      # @return [Integer]
      def min_height
        dialog.height || super
      end

      # Returns the proper widget for the given question
      #
      # @param question [Y2Autoinstall::Ask::Question]
      def widget_for(question)
        if question.type == "boolean"
          CheckBox.new(question)
        elsif question.type == "static_text"
          Label(Id("label_#{question.object_id}"), question.default)
        elsif question.password
          Password.new(question)
        elsif !question.options.empty?
          ComboBox.new(question)
        else
          InputField.new(question)
        end
      end

      # Dialog buttons
      #
      # @return [Array<Yast::Term>]
      def buttons
        b = [back_button, next_button]
        b.insert(1, stop_button) if dialog.timeout.to_i > 0
        b
      end

      # 'Next' button
      #
      # @return [Yast::Term]
      def next_button
        next_label = dialog.ok_label || Yast::Label.NextButton
        PushButton(Id(:next), Opt(:default), next_label)
      end

      # 'Stop' button
      #
      # @return [Yast::Term]
      def stop_button
        PushButton(Id(:stop_counter), Yast::Label.StopButton)
      end

      # 'Back' button
      #
      # @return [Yast::Term]
      def back_button
        back_label = dialog.back_label || Yast::Label.BackButton
        PushButton(Id(:back), back_label)
      end
    end
  end
end
