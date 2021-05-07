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
  module Ask
    class Stage
      # Return the stage corresponding to the given name
      #
      # @raise UnknownStage
      def self.from_name(name)
        stage = KNOWN_STAGES.find { |s| s.name == name }
      end

      # Stage name
      attr_reader :name

      def initialize(name)
        @name = name
      end

      # Determines whether two objects are equivalent
      #
      # @param other [Stage] Stage to compare with
      # @return [Boolean]
      def ==(other)
        name == other.name
      end

      INITIAL = new("initial").freeze
      CONT = new("cont").freeze

      KNOWN_STAGES = [INITIAL, CONT]
      private_constant :KNOWN_STAGES
    end
  end
end
