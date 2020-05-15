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
require "cwm/custom_widget"
require "autoinstall/widgets/storage/crypt_fs"
require "autoinstall/widgets/storage/crypt_key"

module Y2Autoinstallation
  module Widgets
    module Storage
      # Custom widget grouping encryption related attributes
      #
      # @see PartitionUsageTab
      class EncryptionAttrs < CWM::CustomWidget
        # Constructor
        #
        # @param section [Presenters::Partition] presenter for the partition section
        def initialize(section)
          super()
          textdomain "autoinst"
          @section = section
        end

        # @macro seeAbstractWidget
        def label
          ""
        end

        # @macro seeCustomWidget
        def contents
          Left(
            HBox(
              crypt_fs_widget,
              HSpacing(2),
              HSquash(crypt_key_widget)
            )
          )
        end

        # @macro seeAbstractWidget
        def init
          crypt_fs_widget.value  = section.crypt_fs
          crypt_key_widget.value = section.crypt_key
        end

        # Returns the widgets values
        #
        # @return [Hash<String,Object>]
        def values
          {
            "crypt_fs"  => crypt_fs_widget.value,
            "crypt_key" => crypt_key_widget.value
          }
        end

      private

        # @return [Presenters::Partition] presenter for the partition section
        attr_reader :section

        # Widget for setting if the partition will be encrypted
        def crypt_fs_widget
          @crypt_fs_widget ||= CryptFs.new
        end

        # Widget for settings the encryption key
        def crypt_key_widget
          @crypt_key_widget ||= CryptKey.new
        end
      end
    end
  end
end
