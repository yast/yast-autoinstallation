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

require "installation/auto_client"

Yast.import "AutoinstScripts"
Yast.import "Profile"

module Y2Autoinstallation
  module Clients
    class ScriptsAuto < ::Installation::AutoClient
      include Yast::I18n

      def initialize
        super
        textdomain "autoinst"

        Yast.include self, "autoinstall/script_dialogs.rb"
      end

      def import(map)
        Yast::AutoinstScripts.Import(Yast::ProfileHash.new(map))
      end

      def summary
        Yast::AutoinstScripts.Summary
      end

      def reset
        Yast::AutoinstScripts.Import(Yast::ProfileHash.new)
      end

      def modified?
        Yast::AutoinstScripts.GetModified
      end

      def modified
        Yast::AutoinstScripts.SetModified
      end

      def export
        Yast::AutoinstScripts.Export
      end

      def change
        Yast::Wizard.CreateDialog
        Yast::Wizard.SetDesktopIcon("org.opensuse.yast.AutoYaST")
        ScriptsDialog()
      ensure
        Yast::Wizard.CloseDialog
      end
    end
  end
end
