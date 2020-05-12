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
require "cwm/tabs"
require "cwm/replace_point"
require "cwm/common_widgets"
require "autoinstall/widgets/storage/common_partition_attrs"
require "autoinstall/widgets/storage/lvm_partition_attrs"

module Y2Autoinstallation
  module Widgets
    module Storage
      # The tab used to present the general and common options for a partition section
      class PartitionGeneralTab < ::CWM::Tab
        # Constructor
        #
        # @param partition [Presenters::Partition] presenter for a partition section of the profile
        def initialize(partition)
          textdomain "autoinst"

          @partition = partition
        end

        # @macro seeAbstractWidget
        def label
          # TRANSLATORS: name of the tab to display common options
          _("General")
        end

        def contents
          VBox(
            Left(common_partition_attrs),
            Left(section_related_attrs),
            VStretch()
          )
        end

        # @macro seeAbstractWidget
        def values
          [common_partition_attrs, lvm_partition_attrs].reduce({}) do |hsh, widget|
            hsh.merge(widget.values)
          end
        end

        # @macro seeAbstractWidget
        def store
          partition.update(values)
          nil
        end

      private

        # @return [Presenters::Partition] presenter for the partition section
        attr_reader :partition

        # Convenience method to call proper widget depending on the drive type
        def section_related_attrs
          method_name = "#{partition.drive_type}_partition_attrs".downcase

          send(method_name)
        end

        # Options for a all partitions
        #
        # @return [CommonPartitionAttrs]
        def common_partition_attrs
          @common_partition_attrs ||= CommonPartitionAttrs.new(partition)
        end

        # Options for a partition related to an LVM drive section
        #
        # @return [LvmPartitionAttrs]
        def lvm_partition_attrs
          @lvm_partition_attrs ||= LvmPartitionAttrs.new(partition)
        end

        # FIXME
        def disk_partition_attrs
          @disk_partition_attrs ||= NoDependentAttrs.new
        end

        # FIXME
        class NoDependentAttrs < CWM::CustomWidget
          def label
            ""
          end

          def contents
            Empty()
          end
        end
      end
    end
  end
end
