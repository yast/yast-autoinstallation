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

module Y2Autoinstall
  module Widgets
    module Ask
      # Common methods for question field widgets
      module Field
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
          if !@question.value.nil?
            self.value = @question.value.to_s
            return
          end

          if @question.default_value_script
            default_from_script = run_script(@question.default_value_script)
          end
          self.value = default_from_script || @question.default.to_s
        end

        # Stores the widget's value in the question
        #
        # @macro seeAbstractWidget
        def store
          @question.value = value
        end

      private

        # Runs a script and returns the stdout unless it failed
        #
        # @param script [Y2Autoinstallation::ExecutedScript]
        # @return [String,nil]
        def run_script(script)
          script.create_script_file
          return nil unless script.execute

          script.stdout || ""
        end
      end
    end
  end
end
