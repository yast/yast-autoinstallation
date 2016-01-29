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
      Yast.import "Storage"
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
      @text = Ops.add(@text, "</table>")
      @text = Ops.add(@text, "<h3>Storage Data</h3>")

      @tm = Storage.GetTargetMap

      Builtins.foreach(@tm) do |k, v|
        @text = Ops.add(Ops.add(Ops.add(@text, "<h2>"), k), "</h2><table>")
        Builtins.foreach(
          Convert.convert(v, :from => "map", :to => "map <string, any>")
        ) do |key, value|
          @text = Builtins.sformat(
            "%1<tr><td>%2</td><td> = </td><td>%3<br></td></tr>",
            @text,
            key,
            value
          )
        end
        @text = Ops.add(@text, "</table>")
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
