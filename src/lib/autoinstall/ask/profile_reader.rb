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
require "autoinstall/script"
require "autoinstall/ask/stage"

module Y2Autoinstall
  module Ask
    # This class turns an <ask-list> section into a list of Ask::Dialog objects
    class ProfileReader
      # Constructor
      #
      # @param ask_list_section [AskListSection] <ask-list> section from the profiel
      # @param stage [Stage] Consider dialogs/questions from the given stage
      def initialize(ask_list_section, stage: Stage::INITIAL)
        @ask_list_section = ask_list_section
        @stage = stage
      end

      # Returns the dialogs according to the given set of <ask> sections
      #
      # @return [Array<Dialog>] List of dialogs
      def dialogs
        sorted_entries = ask_list_section
          .entries
          .select { |s| (Stage.from_name(s.stage) || Stage::INITIAL) == stage }
          .sort_by { |s| s.dialog ? s.element.to_i : 0 }

        all_dialogs = sorted_entries.each_with_object([]) do |entry, dlgs|
          dialog = find_or_build_dialog(dlgs, entry.dialog)
          [:width, :height, :ok_label, :back_label, :timeout, :title].each do |attr|
            dialog.send("#{attr}=", entry.send(attr)) if entry.send(attr)
          end

          dialog.questions << build_question(entry)
        end

        all_dialogs.sort_by { |d| d.id || -1 }
      end

    private

      # @return [AskListSection]
      attr_reader :ask_list_section

      # @return [Stage]
      attr_reader :stage

      def find_or_build_dialog(dialogs, id)
        dialog = dialogs.find { |d| d.id == id } if id
        return dialog if dialog

        new_dialog = Dialog.new(id)
        dialogs << new_dialog
        new_dialog
      end

      # @param entry [AskSection] Section from the profile
      def build_question(entry)
        question = Question.new(entry.question)

        [:default, :help, :type, :password, :file, :frametitle].each do |attr|
          question.send("#{attr}=", entry.send(attr)) if entry.send(attr)
        end
        question.paths = ((entry.pathlist || []) + [entry.path]).compact
        question.options = (entry.selection || []).map { |s| QuestionOption.new(s.value, s.label) }
        question.script = Y2Autoinstallation::AskScript.new(entry.script.to_hashes) if entry.script

        if entry.default_value_script
          question.default_value_script = Y2Autoinstallation::AskDefaultValueScript.new(
            entry.default_value_script.to_hashes
          )
        end

        question
      end
    end
  end
end
