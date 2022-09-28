# File:  clients/autoinst_post.ycp
# Package:  Auto-installation
# Author:      Anas Nashif <nashif@suse.de>
# Summary:  This module finishes auto-installation and configures
#    the system as described in the profile file.
#
# $Id$

require "autoinstall/entries/registry"
require "autoinstall/importer"

module Yast
  class InstAutopostClient < Client
    def main
      Yast.import "UI"
      textdomain "autoinst"
      Yast.import "Profile"
      Yast.import "AutoInstall"
      Yast.import "Call"
      Yast.import "AutoinstSoftware"
      Yast.import "AutoinstScripts"
      Yast.import "Report"
      Yast.import "Progress"
      Yast.import "PackageSystem"
      Yast.import "AutoinstConfig"
      Yast.include self, "autoinstall/ask.rb"

      Builtins.y2debug("Profile=%1", Profile.current)
      Report.Import(Ops.get_map(Profile.current, "report", {}))

      @autoinstall = SCR.Read(path(".etc.install_inf.AutoYaST"))
      Builtins.y2milestone("cmd line=%1", @autoinstall)
      if !@autoinstall.nil? && Ops.is_string?(@autoinstall)
        AutoinstConfig.ParseCmdLine(Convert.to_string(@autoinstall))
        AutoinstConfig.directory = dirname(AutoinstConfig.filepath)
        Builtins.y2milestone("dir = %1", AutoinstConfig.directory)
      end

      @packages = []
      @resource = ""
      @module_auto = ""

      if Ops.get_map(Profile.current, "report", {}) != {}
        Report.Import(Ops.get_map(Profile.current, "report", {}))
      end

      @help_text = _(
        "<p>\nPlease wait while the system is prepared for autoinstallation.</p>\n"
      )
      @progress_stages = [_("Install required packages")]

      registry = Y2Autoinstallation::Entries::Registry.instance
      modules_to_write = registry.writable_descriptions.select do |description|
        description.managed_keys.any? { |k| Profile.current[k] }
      end
      steps = modules_to_write.size

      steps += 3

      Progress.New(
        _("Preparing System for Automatic Installation"),
        "", # progress_title
        steps, # progress bar length
        @progress_stages,
        [],
        @help_text
      )
      Progress.NextStage
      Progress.Title(_("Checking for required packages..."))

      Builtins.y2milestone("Steps: %1", steps)

      general_settings = Profile.current.fetch("general", {})
      AutoinstGeneral.Import(general_settings) unless general_settings.empty?

      askDialog

      importer = Y2Autoinstallation::Importer.new(Profile.current)
      modules_to_write.each do |description|
        Builtins.y2milestone("current resource: %1", description.resource_name)

        # determine name of client, if not use default name
        module_auto = description.client_name
        importer.import_entry(description)
        out = Call.Function(module_auto, ["Packages"])
        @packages.concat(out["install"] || []) if out
      end

      # Checking result of semantic checks of imported values.
      return :abort unless AutoInstall.valid_imported_values

      # Add all found packages
      Progress.NextStep
      Progress.Title(_("Adding found packages..."))
      @packages = Builtins.filter(@packages) { |p| !PackageSystem.Installed(p) }
      AutoinstSoftware.addPostPackages(@packages)

      # Finish
      Progress.NextStage
      Progress.Finish

      Builtins.y2milestone("Finished required package collection")

      :auto
    end

    def Step(s)
      Progress.NextStep
      Progress.Title(
        Builtins.sformat(_("Checking for packages required for %1..."), s)
      )
      nil
    end

    # Get directory name
    # @param filePath [Strig] string path
    # @return [String] dirname
    def dirname(filePath)
      pathComponents = Builtins.splitstring(filePath, "/")
      last = Ops.get_string(
        pathComponents,
        Ops.subtract(Builtins.size(pathComponents), 1),
        ""
      )
      ret = Builtins.substring(
        filePath,
        0,
        Ops.subtract(Builtins.size(filePath), Builtins.size(last))
      )
      ret
    end
  end
end

Yast::InstAutopostClient.new.main
