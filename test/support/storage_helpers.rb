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

require "y2storage"

module Y2Autoinstall
  module RSpec
    # Storage helpers to be used in tests
    #
    # @note In the future, we should use the helpers in the yast2-storage module.
    # @see https://github.com/yast/yast-storage-ng/blob/9ffcc243001efcc356f81b1b7f1e351f37c1c724/test/support/storage_helpers.rb
    # NOTE: we should move the ones inclu
    module StorageHelpers
      def fake_storage_scenario(scenario)
        Y2Storage::StorageManager.create_test_instance

        meth = scenario.end_with?(".xml") ? :probe_from_xml : :probe_from_yaml
        Y2Storage::StorageManager.instance.public_send(meth, input_file_for(scenario))
      end

      def input_file_for(name, suffix: "yml")
        path = File.join(FIXTURES_PATH, "storage", name)
        path << ".#{suffix}" if File.extname(path).empty?
        path
      end
    end
  end
end
