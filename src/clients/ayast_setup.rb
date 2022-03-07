#  * File:
#  * Package:     Auto-installation
#  * Author:      Uwe Gansert <ug@suse.de>
#  * Summary:
#  *
#  * Changes:     * initial
#    0.2:         * added Pkg::TargetInit
#    0.3:         * support for <post-packages>
#    0.4:         * support for the <ask> feature
#    0.5:         * support for the new "keep install network"
#                   feature of 10.3
#  * Version:     0.5
#  * $Id$
#
#    this client can be called from a running system,
#    to do the autoyast configuration.
#    You have to provide a profile and autoyast will
#    configure your system like in the profile.
#    Only stage2 configuration can be done.
#    yast2 ./ayast_setup.rb setup filename=/tmp/my.xml

require "autoinstall/clients/ayast_setup"
module Yast
  class AyastSetupClient < Client
    include Yast::Logger
    include Y2Autoinstall::Clients::AyastSetup

    def main
      textdomain "autoinst"

      log.info("----------------------------------------")
      log.info("ayast_setup started")

      Yast.import "CommandLine"
      Yast.import "Mode"

      @cmdline = {
        "id"         => "ayast_setup",
        "help"       => _(
          "Client for AutoYaST configuration on the running system"
        ),
        "guihandler" => fun_ref(method(:GUI), "symbol ()"),
        "actions"    => {
          "setup" => {
            "handler" => fun_ref(
              method(:openFile),
              "boolean (map <string, any>)"
            ),
            "help"    => _("Configure the system using given AutoYaST profile"),
            "example" => "setup filename=/path/to/profile dopackages=no"
          }
        },
        "options"    => {
          "filename"   => {
            "type" => "string",
            "help" => _("Path to AutoYaST profile")
          },
          "dopackages" => {
            "type"     => "enum",
            "typespec" => ["yes", "no"],
            "help"     => _("enable/disable all package handling")
          }
        },
        "mappings"   => { "setup" => ["filename", "dopackages"] }
      }

      @ret = CommandLine.Run(@cmdline)

      log.debug("ret = #{@ret}")
      log.info("----------------------------------------")
      log.info("ayast_setup finished")

      nil
    end

    def GUI
      Mode.SetUI("commandline")
      CommandLine.Error(_("Empty parameter list"))
      :dummy
    end
  end
end

Yast::AyastSetupClient.new.main
