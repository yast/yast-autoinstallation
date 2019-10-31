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
    # FIXME: unify with conftree.rb
    ALWAYS_CLONABLE_MODULES ||= ["software", "partitioning", "bootloader"].freeze

    def main
      Yast.import "AutoinstClone"
      Yast.import "Profile"
      Yast.import "XML"
      Yast.import "Popup"
      Yast.import "ProductControl"
      Yast.import "CommandLine"
      Yast.import "Y2ModuleConfig"
      Yast.import "Mode"
      Yast.import "FileUtils"
      Yast.import "Report"
      Yast.import "Installation"
      Yast.import "PackageSystem"

      textdomain "autoinst"

      @moduleList = ""

      if Mode.normal
        if !PackageSystem.Installed("autoyast2")
          ret = PackageSystem.InstallAll(["autoyast2"])
          # The modules/clients has to be reloaded. So the export
          # will be restarted.
          if ret
            SCR.Execute(
              path(".target.bash"),
              "touch #{Installation.restart_file}"
            )
          end
          return
        elsif FileUtils.Exists(Installation.restart_file)
          SCR.Execute(path(".target.remove"), Installation.restart_file)
        end
      end

      Builtins.foreach(Y2ModuleConfig.ModuleMap) do |def_resource, resourceMap|
        clonable = resourceMap["X-SuSE-YaST-AutoInstClonable"] == "true"

        if clonable || ALWAYS_CLONABLE_MODULES.include?(def_resource)
          @moduleList << " " << def_resource
        end
      end

      # if we get no argument or map of options we are not in command line
      if [NilClass, Hash].any? { |c| WFM.Args.first.is_a?(c) }
        params = WFM.Args.first || {}
        doClone(params)
      else
        cmdline = {
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

        ret = CommandLine.Run(cmdline)
        Builtins.y2debug("ret = %1", ret)

      end
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("clone_system finished")

      nil
    end

    def GUI
      Mode.SetUI("commandline")
      CommandLine.Error(_("Empty parameter list"))
      :dummy
    end

    def doClone(options)
      target_path = options["target_path"] || "/root/autoinst.xml"

      # Autoyast overwriting an already existing config file.
      # The warning is only needed while calling "yast clone_system". It is not
      # needed in the installation workflow where it will be checked by the file selection box
      # directly. (bnc#888546)
      if Mode.normal && FileUtils.Exists(target_path)
        # TRANSLATORS: Warning that an already existing autoyast configuration file
        #              will be overwritten.
        return false if !Popup.ContinueCancel(_("File %s exists! Really overwrite?") % target_path)
      end

      Popup.ShowFeedback(
        _("Cloning the system..."),
        # TRANSLATORS: %s is path where profile can be found
        _("The resulting autoyast profile can be found in %s.") % target_path
      )

      AutoinstClone.additional = if Ops.get_string(options, "clone", "") != ""
        Builtins.splitstring(
          Ops.get_string(options, "clone", ""),
          ","
        )
      else
        deep_copy(ProductControl.clone_modules)
      end
      AutoinstClone.Process
      XML.YCPToXMLFile(:profile, Profile.current, target_path)
      Popup.ClearFeedback
      true
    end
  end
end

Yast::CloneSystemClient.new.main
