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

require "autoinstall/widgets/ask_dialog"
require "autoinstall/ask/profile_reader"
require "autoinstall/autoinst_profile/ask_list_section"

Yast.import "Profile"

module Y2Autoinstall
  module Ask
    # Asks the questions defined in the <ask-list> section of an AutoYaST profile
    #
    # ## How does it work?
    #
    # The process starts by grouping all the questions defined in the <ask-list> section
    # by their `dialog` ID. All the questions with the same ID will be placed in the same
    # dialog. If an ID is not specified, the question is shown on a separate dialog.
    #
    # Then the first dialog is presented to the user. When she/he presses the 'Next'
    # button, this runner processes the answers and goes to the next dialog. Processing
    # the response implies:
    #
    # * Updating the profile if an AutoYaST path was given (elements `path` and
    #   `pathlist` from the profile).
    # * Writing the answer to the file, if a `file` element was specified.
    # * Running the given script (`script` element from the profile).
    #
    # @example Ask questions from the profile during the 1st stage
    #   Yast::Profile.ReadXML("autoinst.xml")
    #   runner = Runner.new(profile)
    #   runner.run(:initial)
    class Runner
      # @return [Hash] AutoYaST profile
      attr_reader :profile

      # @param profile [Hash] AutoYaST profile
      def initialize(profile)
        @profile = profile
        @indexes = []
      end

      # Runs the dialogs and processes the user input
      #
      # @param _stage [Symbol] :initial or :cont
      def run(_stage = :initial)
        current_dialog = go_next
        loop do
          break if current_dialog.nil?

          result = run_dialog(current_dialog)
          if result == :back
            current_dialog = go_back
          elsif result == :next
            current_dialog.questions.each { |q| process_question(q) }
            current_dialog = go_next
          end
        end
      end

    private

      # Returns the AskListSection from the profile
      #
      # @return [AskListSection]j
      def ask_list
        return @ask_list if @ask_list

        section = profile.fetch("general", {}).fetch("ask-list", [])
        @ask_list = Y2Autoinstall::AutoinstProfile::AskListSection.new_from_hashes(section)
      end

      NEXT_DIALOG_FILE = "/tmp/next_dialog".freeze

      # Run the given dialog
      #
      # @param dialog [Y2Autoinstall::Ask::Dialog] Ask dialog specification
      # @return [Symbol] :next or :back
      def run_dialog(dialog)
        ask_dialog = Y2Autoinstall::Widgets::AskDialog.new(
          dialog, disable_back_button: first?(dialog)
        )
        ask_dialog.run
      end

      # Finds the ID of the next dialog
      #
      # It checks for a file located at {NEXT_DIALOG_FILE} which contains the number
      # of the following dialog. If it does not exist, it goes with the dialog after
      # the current one.
      #
      # @return [Integer] Next dialog ID
      def find_next_dialog
        return unless ::File.exist?(NEXT_DIALOG_FILE)

        next_dialog = File.read(NEXT_DIALOG_FILE)
        FileUtils.rm(NEXT_DIALOG_FILE)
        next_dialog.to_i
      end

      # Index of the current dialog
      #
      # @return [Integer] Index of `-1` if no dialog is open yet.
      def current_index
        @indexes.last || -1
      end

      # Goes one dialog back
      #
      # @return [Dialog] Returns the previous dialog
      def go_back
        @indexes.pop
        dialogs[current_index]
      end

      # Goes one dialog forward
      #
      # @return [Dialog,nil] Returns the following dialog or `nil` if there are no more dialogs
      def go_next
        # FIXME: find_next_dialog returns the ID, but we are using the index here.
        next_index = find_next_dialog || (current_index + 1)
        @indexes.push(next_index)
        dialogs[next_index]
      end

      # Dialogs specifications from the profile
      #
      # @return [Array<Dialog>] List of dialogs from the given profile
      def dialogs
        @dialogs ||= ProfileReader.new(ask_list).dialogs
      end

      # Determines whether the given dialog is the first or not
      #
      # @param dialog [Dialog]
      # @return [Boolean]
      def first?(dialog)
        dialogs.first == dialog
      end

      # Processes the answer for the given question
      #
      # 1. Updates the profile
      # 2. Writes the value to the file
      # 3. Runs the script
      #
      # @param question [Question] Question to process
      def process_question(question)
        update_profile(question)
        write_value(question)
        run_script(question)
      end

      # Sets the elements in the question's path list to the value entered by the user
      #
      # @param question [Question]
      def update_profile(question)
        # FIXME: convert to the proper type (:symbol, string, boolean and so on)
        question.paths.each do |path|
          Yast::Profile.set_element_by_path(path, question.value.to_s, profile)
        end
      end

      # Write the answer to the given file
      #
      # @param question [Question]
      def write_value(question)
        return if question.file.nil?

        File.write(question.file, question.value.to_s)
      end

      # Runs the associated script if defined
      #
      # @param question [Question]
      def run_script(question)
        question.script&.execute
      end
    end
  end
end
