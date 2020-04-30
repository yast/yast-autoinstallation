# Copyright (c) [2020] SUSE LLC
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
require "delegate"

module Y2Autoinstallation
  module Presenters
    # Base class to create presenters for objects that implement the interface
    # defined by Y2Storage::AutoinstProfile::SectionWithAttributes
    #
    # The current implementation relies on SimpleDelegator, which means
    # all methods of the corresponding section class are exposed. That may
    # change in the future in favor of a more granular approach (eg. using
    # Forwardable).
    class Section < SimpleDelegator
      include Yast::I18n

      # Constructor
      #
      # @param section [Y2Storage::AutoinstProfile::SectionWithAttributes] the
      #   concrete type of section depends on the presenter subclass
      def initialize(section)
        textdomain "autoinst"
        __setobj__(section)
      end

      # Original profile section
      #
      # @return [Y2Storage::AutoinstProfile::SectionWithAttributes] presented object
      def section
        __getobj__
      end

      # String representation of the object
      #
      # @return [String]
      def to_s
        # By default, SimpleDelegator forwards this to the wrapped object. That can be
        # pretty confusing, so let's implement the typical Ruby #to_s.
        "#<#{obj_str}>"
      end

      # String representation of the state of the object
      #
      # @return [String]
      def inspect
        # Avoid SimpleDelegator forwarding to the wrapped section, see comment at #to_s
        "#<#{obj_str} @section=#{section.inspect}>"
      end

      # Id that can be used to identify the section object
      #
      # This can be used, for example, to create ids for the widgets related to
      # the presented section.
      #
      # @return [Integer]
      def section_id
        section.object_id
      end

      # Updates the Autoinst section
      #
      # @param values [Hash] Values to update
      def update(values)
        # FIXME: this cleanup should be implemented by the section class,
        # directly in #init_from_hashes or in any similar method
        clean_section
        section.init_from_hashes(values)
      end

    private

      # Resets all known attributes in the section
      #
      # FIXME: ideally we wouldn't need to implement this kind of things in
      # the presenter
      def clean_section
        section.class.attributes.each do |attr|
          section.public_send("#{attr[:name]}=", nil)
        end
      end

      # See {#to_s} and {#inspect}
      def obj_str
        "#{self.class}:#{object_id}"
      end
    end
  end
end
