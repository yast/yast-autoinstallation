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

require "autoinstall/ask/dialog"
require "autoinstall/ask/question"
require "autoinstall/ask/question_option"
require "autoinstall/ask_script"

module Y2Autoinstall
  module Ask
    # This class turns an <ask-list> section into a list of Ask::Dialog objects
    class ProfileReader
      # Constructor
      #
      # @param ask_list_section [AskListSection] <ask-list> section from the profiel
      # @param stage [Symbol] :initial or :cont
      def initialize(ask_list_section, stage: :initial)
        @ask_list_section = ask_list_section
        @stage = stage
      end

      # Returns the dialogs according to the given set of <ask> sections
      #
      # @return [Array<Dialog>] List of dialogs
      def dialogs
        sorted_entries = ask_list_section
          .entries
          .select { |s| (s.stage&.to_sym || :initial) == stage }
          .sort_by { |s| s.dialog ? s.element.to_i : 0 }

        all_dialogs = sorted_entries.each_with_object([]) do |entry, dlgs|
          dialog = find_dialog(dlgs, entry.dialog)
          [:width, :height, :ok_label, :back_label, :timeout, :title].each do |attr|
            dialog.send("#{attr}=", entry.send(attr)) if entry.send(attr)
          end

          dialog.questions << build_question(entry)
        end

        wo_id, with_id = all_dialogs.partition { |d| d.id.nil? }
        wo_id + with_id.sort_by(&:id)
      end

    private

      # @return [Array<AskListSection>]
      attr_reader :ask_list_section

      # @return [Symbol]
      attr_reader :stage

      def find_dialog(dialogs, id)
        dialog = dialogs.find { |d| d.id == id } if id
        return dialog if dialog

        new_dialog = Dialog.new(id)
        dialogs << new_dialog
        new_dialog
      end

      # @param entry [AskSection] Section from the profile
      def build_question(entry)
        question = Question.new(entry.question, entry.element)

        [:stage, :default, :help, :type, :password, :file].each do |attr|
          question.send("#{attr}=", entry.send(attr))
        end
        question.paths = ((entry.pathlist || []) + [entry.path]).compact
        question.options = (entry.selection || []).map { |s| QuestionOption.new(s.value, s.label) }
        question.script = build_script(entry.script) if entry.script
        if entry.default_value_script
          question.default_value_script = build_script(entry.default_value_script)
        end

        question
      end

      # @param section [ScriptSection] Script section from the profile
      def build_script(section)
        Y2Autoinstall::AskScript.new(section.to_hashes)
      end
    end
  end
end
