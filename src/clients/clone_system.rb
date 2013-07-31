# encoding: utf-8

# File:        clients/clone_system.ycp
# Package:     Auto-installation
# Author:      Uwe Gansert <ug@suse.de>
# Summary:     This client is clones some settings of the
#              system.
#
# Changes:     * initial - just do a simple clone
# $Id$
module Yast
  class CloneSystemClient < Client
    def main
      Yast.import "AutoinstClone"
      Yast.import "Profile"
      Yast.import "XML"
      Yast.import "Popup"
      Yast.import "ProductControl"
      Yast.import "CommandLine"
      Yast.import "Y2ModuleConfig"
      Yast.import "Mode"

      textdomain "autoinst"

      @moduleList = ""

      Builtins.foreach(Y2ModuleConfig.ModuleMap) do |def_resource, resourceMap|
        clonable = Ops.get_string(
          resourceMap,
          "X-SuSE-YaST-AutoInstClonable",
          "false"
        ) == "true"
        if clonable || def_resource == "bootloader" ||
            def_resource == "partitioning" ||
            def_resource == "software"
          @moduleList = Builtins.sformat("%1 %2", @moduleList, def_resource)
        end
      end

      @cmdline = {
        "id"         => "clone_system",
        "help"       => _(
          "Client for creating an AutoYaST profile based on the currently running system"
        ),
        "guihandler" => fun_ref(method(:GUI), "symbol ()"),
        "actions"    => {
          "modules" => {
            "handler" => fun_ref(
              method(:doClone),
              "boolean (map <string, any>)"
            ),
            "help"    => Builtins.sformat(_("known modules: %1"), @moduleList),
            "example" => "modules clone=software,partitioning"
          }
        },
        "options"    => {
          "clone" => {
            "type" => "string",
            "help" => _("comma separated list of modules to clone")
          }
        },
        "mappings"   => { "modules" => ["clone"] }
      }


      @ret = true

      if Builtins.size(WFM.Args) == 0
        doClone({})
      else
        @ret = CommandLine.Run(@cmdline)
      end
      Builtins.y2debug("ret = %1", @ret)
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("clone_system finished") 

      #    doClone();

      nil
    end

    def GUI
      Mode.SetUI("commandline")
      CommandLine.Error(_("Empty parameter list"))
      :dummy
    end

    def doClone(options)
      options = deep_copy(options)
      Popup.ShowFeedback(
        _("Cloning the system..."),
        _("The resulting autoyast profile can be found in /root/autoinst.xml.")
      )

      if Ops.get_string(options, "clone", "") != ""
        AutoinstClone.additional = Builtins.splitstring(
          Ops.get_string(options, "clone", ""),
          ","
        )
      else
        AutoinstClone.additional = deep_copy(ProductControl.clone_modules)
      end
      AutoinstClone.Process
      XML.YCPToXMLFile(:profile, Profile.current, "/root/autoinst.xml")
      Popup.ClearFeedback
      true
    end
  end
end

Yast::CloneSystemClient.new.main
