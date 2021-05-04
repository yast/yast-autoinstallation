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
require "cwm/popup"
require "cwm/common_widgets"

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
        VBox(*widgets)
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
        [back_button, next_button]
      end

      # 'Next' button
      #
      # @return [Yast::Term]
      def next_button
        next_label = dialog.ok_label || Yast::Label.NextButton
        PushButton(Id(:next), Opt(:default), next_label)
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
