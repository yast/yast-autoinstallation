# encoding: utf-8

# File:	clients/autoinst_post.ycp
# Package:	Auto-installation
# Author:      Anas Nashif <nashif@suse.de>
# Summary:	This module finishes auto-installation and configures
#		the system as described in the profile file.
#
# $Id$
module Yast
  class InstAutopostClient < Client
    def main
      Yast.import "UI"
      textdomain "autoinst"
      Yast.import "Profile"
      Yast.import "AutoInstall"
      Yast.import "AutoinstGeneral"
      Yast.import "Call"
      Yast.import "Y2ModuleConfig"
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
      if @autoinstall != nil && Ops.is_string?(@autoinstall)
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

      @steps = Builtins.size(Builtins.filter(Y2ModuleConfig.ModuleMap) do |p, d|
        (Ops.get_string(d, "X-SuSE-YaST-AutoInst", "") == "all" ||
          Ops.get_string(d, "X-SuSE-YaST-AutoInst", "") == "write") &&
          Builtins.haskey(
            Profile.current,
            Ops.get_string(d, "X-SuSE-YaST-AutoInstResource", p)
          )
      end)


      @steps = Ops.add(@steps, 3)

      Progress.New(
        _("Preparing System for Automatic Installation"),
        "", # progress_title
        @steps, # progress bar length
        @progress_stages,
        [],
        @help_text
      )
      Progress.NextStage
      Progress.Title(_("Checking for required packages..."))

      askDialog
      # FIXME: too late here, even though it would be the better place
      # if (Profile::current["general"]:$[] != $[])
      #     AutoinstGeneral::Import(Profile::current["general"]:$[]);
      # AutoinstGeneral::SetSignatureHandling();

      Builtins.y2milestone("Steps: %1", @steps)

      Builtins.foreach(Y2ModuleConfig.ModuleMap) do |p, d|
        if Ops.get_string(d, "X-SuSE-YaST-AutoInst", "") == "all" ||
            Ops.get_string(d, "X-SuSE-YaST-AutoInst", "") == "write"
          if Builtins.haskey(d, "X-SuSE-YaST-AutoInstResource") &&
              Ops.get_string(d, "X-SuSE-YaST-AutoInstResource", "") != ""
            @resource = Ops.get_string(
              d,
              "X-SuSE-YaST-AutoInstResource",
              "unknown"
            )
          else
            @resource = p
          end

          Builtins.y2milestone("current resource: %1", @resource)

          # determine name of client, if not use default name
          if Builtins.haskey(d, "X-SuSE-YaST-AutoInstClient")
            @module_auto = Ops.get_string(
              d,
              "X-SuSE-YaST-AutoInstClient",
              "none"
            )
          else
            @module_auto = Builtins.sformat("%1_auto", p)
          end

          result = {}

          if Builtins.haskey(Profile.current, @resource)
            Builtins.y2milestone("Importing configuration for %1", p)
            tomerge = Ops.get_string(d, "X-SuSE-YaST-AutoInstMerge", "")
            tomergetypes = Ops.get_string(
              d,
              "X-SuSE-YaST-AutoInstMergeTypes",
              ""
            )
            _MergeTypes = Builtins.splitstring(tomergetypes, ",")

            if Ops.greater_than(Builtins.size(tomerge), 0)
              i = 0
              Builtins.foreach(Builtins.splitstring(tomerge, ",")) do |res|
                if Ops.get_string(_MergeTypes, i, "map") == "map"
                  Ops.set(result, res, Ops.get_map(Profile.current, res, {}))
                else
                  Ops.set(result, res, Ops.get_list(Profile.current, res, []))
                end
                i = Ops.add(i, 1)
              end
              if Ops.get_string(d, "X-SuSE-YaST-AutoLogResource", "true") == "true"
                Builtins.y2milestone("Calling auto client with: %1", result)
              else
                Builtins.y2milestone(
                  "logging for resource %1 turned off",
                  @resource
                )
                Builtins.y2debug("Calling auto client with: %1", result)
              end
              if Ops.greater_than(Builtins.size(result), 0)
                Step(p)
                Call.Function(@module_auto, ["Import", Builtins.eval(result)])
                out = Convert.to_map(Call.Function(@module_auto, ["Packages"]))
                @packages = Convert.convert(
                  Builtins.union(@packages, Ops.get_list(out, "install", [])),
                  :from => "list",
                  :to   => "list <string>"
                )
              end
            elsif Ops.get_string(d, "X-SuSE-YaST-AutoInstDataType", "map") == "map"
              if Ops.get_string(d, "X-SuSE-YaST-AutoLogResource", "true") == "true"
                Builtins.y2milestone(
                  "Calling auto client with: %1",
                  Builtins.eval(Ops.get_map(Profile.current, @resource, {}))
                )
              else
                Builtins.y2milestone(
                  "logging for resource %1 turned off",
                  @resource
                )
                Builtins.y2debug(
                  "Calling auto client with: %1",
                  Builtins.eval(Ops.get_map(Profile.current, @resource, {}))
                )
              end
              if Ops.greater_than(
                  Builtins.size(Ops.get_map(Profile.current, @resource, {})),
                  0
                )
                Step(p)
                Call.Function(
                  @module_auto,
                  [
                    "Import",
                    Builtins.eval(Ops.get_map(Profile.current, @resource, {}))
                  ]
                )
                out = Convert.to_map(Call.Function(@module_auto, ["Packages"]))
                @packages = Convert.convert(
                  Builtins.union(@packages, Ops.get_list(out, "install", [])),
                  :from => "list",
                  :to   => "list <string>"
                )
              end
            else
              if Ops.greater_than(
                  Builtins.size(Ops.get_list(Profile.current, @resource, [])),
                  0
                )
                Step(p)
                Call.Function(
                  @module_auto,
                  [
                    "Import",
                    Builtins.eval(Ops.get_list(Profile.current, @resource, []))
                  ]
                )
                out = Convert.to_map(Call.Function(@module_auto, ["Packages"]))
                @packages = Convert.convert(
                  Builtins.union(@packages, Ops.get_list(out, "install", [])),
                  :from => "list",
                  :to   => "list <string>"
                )
              end
            end
          end
        end
      end

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
