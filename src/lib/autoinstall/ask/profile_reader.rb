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
          dialog.width = entry.width if entry.width
          dialog.height = entry.height  if entry.height
          dialog.ok_label = entry.ok_label if entry.ok_label
          dialog.back_label = entry.back_label if entry.back_label
          dialog.timeout = entry.timeout if entry.timeout
          dialog.title = entry.title if entry.title

          question = Question.new(entry.question, entry.element).tap do |q|
            q.stage = entry.stage
            q.default = entry.default
            q.help = entry.help
            q.type = entry.type
            q.password = entry.password
            q.paths = ((entry.pathlist || []) + [entry.path]).compact
            q.file = entry.file
            q.script = Y2Autoinstall::AskScript.new(entry.script.to_hashes) if entry.script
            if entry.default_value_script
              q.default_value_script = Y2Autoinstall::AskScript.new(
                entry.default_value_script.to_hashes
              )
            end
            q.options = (entry.selection || []).map do |s|
              QuestionOption.new(s.value, s.label)
            end
          end

          dialog.questions << question
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
    end
  end
end
