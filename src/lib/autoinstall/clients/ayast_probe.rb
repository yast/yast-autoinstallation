# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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
  module Clients
    class AyastProbe
      include Yast::UIShortcuts

      def main
        Yast.import "UI"
        Yast.import "Stage"
        Yast::Stage.Set("initial")
        Yast.import "AutoInstallRules"
        Yast.import "Label"
        Yast::AutoInstallRules.ProbeRules

        @attrs =
          #                             "NonLinuxPartitions":Yast::AutoInstallRules::NonLinuxPartitions,
          #                             "LinuxPartitions":Yast::AutoInstallRules::LinuxPartitions,
          #                             "disksize":Yast::AutoInstallRules::disksize
          {
            "installed_product"         => Yast::AutoInstallRules.installed_product,
            "installed_product_version" => Yast::AutoInstallRules.installed_product_version(
            ),
            "hostname"                  => Yast::AutoInstallRules.hostname,
            "hostaddress"               => Yast::AutoInstallRules.hostaddress,
            "network"                   => Yast::AutoInstallRules.network,
            "domain"                    => Yast::AutoInstallRules.domain,
            "arch"                      => Yast::AutoInstallRules.arch,
            "karch"                     => Yast::AutoInstallRules.karch,
            "product"                   => Yast::AutoInstallRules.product,
            "product_vendor"            => Yast::AutoInstallRules.product_vendor,
            "board_vendor"              => Yast::AutoInstallRules.board_vendor,
            "board"                     => Yast::AutoInstallRules.board,
            "memsize"                   => Yast::AutoInstallRules.memsize,
            "totaldisk"                 => Yast::AutoInstallRules.totaldisk,
            "hostid"                    => Yast::AutoInstallRules.hostid,
            "mac"                       => Yast::AutoInstallRules.mac,
            "linux"                     => Yast::AutoInstallRules.linux,
            "others"                    => Yast::AutoInstallRules.others,
            "xserver"                   => Yast::AutoInstallRules.xserver
          }
        @text = "<h3>Keys for rules</h3><table>"
        Yast::Builtins.foreach(@attrs) do |k, v|
          @text = Yast::Ops.add(
            @text,
            Yast::Builtins.sformat(
              "<tr><td>%1</td><td> = </td><td>%2<br></td></tr>",
              k,
              v
            )
          )
        end

        Yast::UI.OpenDialog(
          Opt(:defaultsize),
          VBox(RichText(@text), PushButton(Opt(:default), Yast::Label.OKButton))
        )
        Yast::UI.UserInput
        Yast::UI.CloseDialog

        nil
      end
    end
  end
end
