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

module Y2Autoinstallation
  module Widgets
    # Mixin to extend the #value= method for editable ComboBox widgets
    #
    # Ideally, this behaviour might be implemented in the original
    # CWM ComboBox class.
    #
    # @example Define an editable combo box
    #  class MyComboBox < CWM::ComboBox
    #    include EditableComboBox
    #
    #    def opt
    #      [:editable]
    #    end
    #  end
    #
    # As you can see in the example, you need to define the
    # `#opt` method to include the `:editable` option.
    module EditableComboBox
      # Changes the list of items
      #
      # @macro seeComboBox
      def change_items(new_items)
        @items = new_items
        super(new_items)
      end

      # @macro seeAbstractWidget
      def value=(val)
        change_items(items + [[val, val]]) if val && !items.map(&:first).include?(val)
        super(val)
      end
    end
  end
end
