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

require "installation/autoinst_profile/section_with_attributes"

module Y2Autoinstall
  module AutoinstProfile
    class AskSelectionEntry < ::Installation::AutoinstProfile::SectionWithAttributes
      def self.attributes
        [
          { name: :value, allow_blank: true },
          { name: :label, allow_blank: true }
        ]
      end

      define_attr_accessors

      # @!attribute value
      #   @return [String,nil] Entry value
      #
      # @!attribute label
      #   @return [String,nil] Entry label
    end
  end
end
