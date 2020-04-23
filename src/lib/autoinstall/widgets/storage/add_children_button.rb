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

module Y2Autoinstallation
  module Widgets
    module Storage
      # This class provides a button to add 'partition' sections
      #
      # In an AutoYaST profile, a 'partition' section is used to define a
      # partition, a logical volume, a RAID member, etc.
      class AddChildrenButton < CWM::PushButton
        extend Yast::I18n

        # Constructor
        #
        # @param controller [Y2Autoinstallation::StorageController] UI controller
        # @param section [Y2Storage::AutoinstProfile::DriveSection] Drive section of the profile
        def initialize(controller, section)
          textdomain "autoinst"
          @controller = controller
          @section = section
        end

        TYPE_LABELS = {
          CT_DISK: N_("Partition"),
          CT_RAID: N_("Partition"),
          CT_LVM:  N_("Partition")
        }.freeze

        def label
          type_label = _(TYPE_LABELS[section.type])
          format(_("Add %{type_label}"), type_label: type_label)
        end

        # @macro seeAbstractWidget
        def handle
          # FIXME: the controller could keep track of the current section
          controller.add_partition(section)
          :redraw
        end

      private

        # @return [Y2Autoinstallation::StorageController]
        attr_reader :controller

        # @return [Y2Storage::AutoinstProfile::DriveSection]
        attr_reader :section
      end
    end
  end
end
