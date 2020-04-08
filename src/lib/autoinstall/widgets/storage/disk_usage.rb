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
require "cwm/common_widgets"
require "autoinstall/widgets/editable_combo_box"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Widget to determine how the disk will be used
      #
      # It corresponds to the `use` element in the profile.
      class DiskUsage < CWM::ComboBox
        extend Yast::I18n
        include EditableComboBox

        def initialize
          textdomain "autoinst"
          super
        end

        # @macro seeAbstractWidget
        def label
          _("Reuse")
        end

        # @macro seeAbstractWidget
        def opt
          [:editable]
        end

        ITEMS = [:all, :free, :linux].freeze
        ITEMS_LABELS = {
          all:   N_("All partitions"),
          linux: N_("Linux partitions"),
          free:  N_("Only free space")
        }.freeze
        private_constant :ITEMS, :ITEMS_LABELS

        # @macro seeComboBox
        def items
          @items ||= ITEMS.map do |opt|
            [opt.to_s, _(ITEMS_LABELS[opt])]
          end
        end
      end
    end
  end
end
