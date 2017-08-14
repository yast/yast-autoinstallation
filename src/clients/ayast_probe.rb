# encoding: utf-8

# File:        clients/ayast_probe.ycp
# Package:     Auto-installation
# Author:      Uwe Gansert <ug@suse.de>
# Summary:     This client is more or less for debugging.
#              It dumps interesting autoyast values and is
#              not as scaring as reading y2log just for some info
#
# Changes:     * initial - just dumps the rule values
# $Id$
module Yast
  class AyastProbeClient < Client
    def main
      Yast.import "UI"
      Yast.import "Stage"
      Stage.Set("initial")
      Yast.import "AutoInstallRules"
      Yast.import "Label"
      AutoInstallRules.ProbeRules

      @attrs =
        #                             "NonLinuxPartitions":AutoInstallRules::NonLinuxPartitions,
        #                             "LinuxPartitions":AutoInstallRules::LinuxPartitions,
        #                             "disksize":AutoInstallRules::disksize
        {
          "installed_product"         => AutoInstallRules.installed_product,
          "installed_product_version" => AutoInstallRules.installed_product_version(
          ),
          "hostname"                  => AutoInstallRules.hostname,
          "hostaddress"               => AutoInstallRules.hostaddress,
          "network"                   => AutoInstallRules.network,
          "domain"                    => AutoInstallRules.domain,
          "arch"                      => AutoInstallRules.arch,
          "karch"                     => AutoInstallRules.karch,
          "product"                   => AutoInstallRules.product,
          "product_vendor"            => AutoInstallRules.product_vendor,
          "board_vendor"              => AutoInstallRules.board_vendor,
          "board"                     => AutoInstallRules.board,
          "memsize"                   => AutoInstallRules.memsize,
          "totaldisk"                 => AutoInstallRules.totaldisk,
          "hostid"                    => AutoInstallRules.hostid,
          "mac"                       => AutoInstallRules.mac,
          "linux"                     => AutoInstallRules.linux,
          "others"                    => AutoInstallRules.others,
          "xserver"                   => AutoInstallRules.xserver
        }
      @text = "<h3>Keys for rules</h3><table>"
      Builtins.foreach(@attrs) do |k, v|
        @text = Ops.add(
          @text,
          Builtins.sformat(
            "<tr><td>%1</td><td> = </td><td>%2<br></td></tr>",
            k,
            v
          )
        )
      end

      UI.OpenDialog(
        Opt(:defaultsize),
        VBox(RichText(@text), PushButton(Opt(:default), Label.OKButton))
      )
      UI.UserInput
      UI.CloseDialog

      nil
    end
  end
end

Yast::AyastProbeClient.new.main
