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
require "autoinstall/script_runner"

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
    #   runner = Runner.new(Yast::Profile.current, stage: Stage::INITIIAL)
    #   runner.run
    class Runner
      include Yast::Logger

      # @return [Hash] AutoYaST profile
      attr_reader :profile
      # @return [Stage] Stage to run; only the dialogs/questions for the given
      #   stage are shown.
      attr_reader :stage

      # @param profile [Hash] AutoYaST profile
      # @param stage [Stage] Consider dialogs/questions from the given stage
      def initialize(profile, stage:)
        @profile = profile
        @indexes = []
        @stage = stage
      end

      # Runs the dialogs and processes the user input
      #
      def run
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

        section = profile.fetch_as_hash("general").fetch_as_array("ask-list")
        @ask_list = Y2Autoinstall::AutoinstProfile::AskListSection.new_from_hashes(section)
      end

      # Run the given dialog
      #
      # @param dialog [Y2Autoinstall::Ask::Dialog] Ask dialog specification
      # @return [Symbol] :next or :back
      def run_dialog(dialog)
        ask_dialog = Y2Autoinstall::Widgets::AskDialog.new(
          dialog, disable_back_button: first?
        )
        ask_dialog.run
      end

      DIALOG_FILE = "/tmp/next_dialog".freeze
      MAX_DIALOG_FILE_SIZE = 1024
      private_constant :MAX_DIALOG_FILE_SIZE

      # Finds the ID of the next dialog
      #
      # It checks for a regular file located at {DIALOG_FILE} which contains
      # the number of the following dialog. If it does not exist, it goes with
      # the dialog after the current one.
      #
      # For security reasons, it checks whether the size of the file makes
      # sense for this use case, to not load a big chunk of data into memory by
      # mistake.
      #
      # @return [Integer,nil] Next dialog ID
      def find_next_dialog_index
        return unless File.file?(DIALOG_FILE) && File.size(DIALOG_FILE) <= MAX_DIALOG_FILE_SIZE

        next_dialog = File.read(DIALOG_FILE)
        FileUtils.rm(DIALOG_FILE)
        dialog_id = next_dialog.to_i
        return unless dialog_id

        next_dialog = dialogs.find { |d| d.id == dialog_id }
        dialogs.index(next_dialog)
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
        next_index = find_next_dialog_index || (current_index + 1)
        @indexes.push(next_index)
        dialogs[next_index]
      end

      # Dialogs specifications from the profile
      #
      # @return [Array<Dialog>] List of dialogs from the given profile
      def dialogs
        @dialogs ||= ProfileReader.new(ask_list, stage: stage).dialogs
      end

      # Determines whether the given dialog is the first or not
      #
      # @return [Boolean]
      def first?
        @indexes.size == 1
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
        question.paths.each do |path|
          if question.value.nil?
            log.error "Question '#{question.text}' does not have any value."
            next
          end

          Yast::Profile.set_element_by_path(path, question.value, profile)
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
        return unless question.script

        question.script.create_script_file
        env = question.script.environment ? { "VAL" => question.value } : {}
        script_runner.run(question.script, env: env)
      end

      # Returns a ScriptRunner instance to run scripts
      #
      # @return [ScriptRunner]
      def script_runner
        @script_runner ||= Y2Autoinstall::ScriptRunner.new
      end
    end
  end
end
