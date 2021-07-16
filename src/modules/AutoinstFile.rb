# File:  modules/AutoinstFile.ycp
# Package:  AutoYaST
# Authors:  Anas Nashif (nashif@suse.de)
# Summary:  Handle complete configuration file dumps
#
# $Id$
require "yast"

module Yast
  class AutoinstFileClass < Module
    def main
      textdomain "autoinst"

      Yast.import "AutoinstConfig"
      Yast.import "Installation"
      Yast.import "Summary"

      Yast.include self, "autoinstall/io.rb"

      # default value of settings modified
      @modified = false

      @Files = []
    end

    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      Builtins.y2milestone("SetModified")
      @modified = true

      nil
    end

    # Functions which returns if the settings were modified
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end

    # Settings Summary
    def Summary
      summary = ""
      summary = Summary.AddHeader(summary, _("Configured Files:"))
      if Ops.greater_than(Builtins.size(@Files), 0)
        summary = Summary.OpenList(summary)
        Builtins.foreach(@Files) do |file|
          summary = Summary.AddListItem(
            summary,
            Ops.get_string(file, "file_path", "")
          )
        end
        summary = Summary.CloseList(summary)
      else
        summary = Summary.AddLine(summary, Summary.NotConfigured)
      end
      summary
    end

    # Import Settings
    def Import(settings)
      settings = deep_copy(settings)
      @Files = deep_copy(settings)
      true
    end

    # Export Settings
    def Export
      deep_copy(@Files)
    end

    # Write Settings
    def Write
      Yast.import "AutoInstall"
      Builtins.y2milestone("Writing Files to the system")
      return true if Builtins.size(@Files) == 0

      counter = 0
      success = false

      Builtins.foreach(@Files) do |file|
        alternate_location = Builtins.sformat(
          "%1/%2",
          AutoinstConfig.files_dir,
          counter
        )
        if Ops.subtract(
          Builtins.size(Ops.get_string(file, "file_path", "dummy")),
          1
        ) ==
            Builtins.findlastof(Ops.get_string(file, "file_path", ""), "/")
          # directory
          SCR.Execute(
            path(".target.mkdir"),
            Ops.get_string(file, "file_path", alternate_location)
          )
        elsif Ops.get_string(file, "file_contents", "") != ""
          Builtins.y2milestone(
            "AutoInstall: Copying file %1",
            Ops.get_string(file, "file_path", alternate_location)
          )
          SCR.Write(
            path(".target.string"),
            Ops.get_string(file, "file_path", alternate_location),
            Ops.get_string(file, "file_contents", "")
          )
        elsif Ops.get_string(file, "file_location", "") != ""
          if Builtins.issubstring(
            Ops.get_string(file, "file_location", ""),
            "relurl://"
          )
            l = Ops.get_string(file, "file_location", "")
            l = Builtins.substring(l, 9)
            newloc = ""
            if AutoinstConfig.scheme == "relurl"
              Builtins.y2milestone("autoyast profile was relurl too")
              newloc = Convert.to_string(
                SCR.Read(path(".etc.install_inf.ayrelurl"))
              )
              tok = URL.Parse(newloc)
              Builtins.y2milestone("tok = %1", tok)
              newloc = Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(
                      Ops.add(Ops.get_string(tok, "scheme", ""), "://"),
                      Ops.get_string(tok, "host", "")
                    ),
                    "/"
                  ),
                  dirname(Ops.get_string(tok, "path", ""))
                ),
                l
              )
            else
              newloc = Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(
                      Ops.add(AutoinstConfig.scheme, "://"),
                      AutoinstConfig.host
                    ),
                    "/"
                  ),
                  AutoinstConfig.directory
                ),
                l
              )
            end
            Ops.set(file, "file_location", newloc)
            Builtins.y2milestone("changed relurl to %1 for file", newloc)
          end
          file_location = File.join(Installation.destdir, file["file_path"] || alternate_location)
          Builtins.y2milestone(
            "trying to get file from %1 storing in %2",
            Ops.get_string(file, "file_location", ""),
            file_location
          )
          if !GetURL(
            Ops.get_string(file, "file_location", ""),
            file_location
          )
            Builtins.y2error("file could not be retrieved")
          else
            Builtins.y2milestone("file was retrieved")
          end
        end
        if Ops.get_string(file, "file_permissions", "") != ""
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat(
              "chmod %1 %2",
              Ops.get_string(file, "file_permissions", ""),
              Ops.get_string(file, "file_path", alternate_location)
            )
          )
        end
        if Ops.get_string(file, "file_owner", "") != ""
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat(
              "chown %1 %2",
              Ops.get_string(file, "file_owner", ""),
              Ops.get_string(file, "file_path", alternate_location)
            )
          )
        end
        script = Ops.get_map(file, "file_script", {})
        if script != {}
          current_logdir = AutoinstConfig.logs_dir
          name_tok = Builtins.splitstring(
            Ops.get_string(file, "file_path", alternate_location),
            "/"
          )
          scriptName = ""
          if Ops.greater_than(Builtins.size(name_tok), 0)
            name = Ops.get_string(
              name_tok,
              Ops.subtract(Builtins.size(name_tok), 1),
              ""
            )
            scriptName = Ops.add("script_", name)
          end
          scriptPath = Builtins.sformat(
            "%1/%2",
            AutoinstConfig.scripts_dir,
            scriptName
          )
          Builtins.y2milestone("Writing (file) script into %1", scriptPath)
          got_script = false
          if Ops.get_string(script, "location", "") != ""
            Builtins.y2milestone(
              "getting script: %1",
              Ops.get_string(script, "location", "")
            )
            if !GetURL(Ops.get_string(script, "location", ""), scriptPath)
              Builtins.y2error(
                "script %1 could not be retrieved",
                Ops.get_string(script, "location", "")
              )
            else
              got_script = true
            end
          end
          if !got_script
            SCR.Write(
              path(".target.string"),
              scriptPath,
              Ops.get_string(script, "source", "echo Empty script!")
            )
          end
          scriptInterpreter = Ops.get_string(script, "interpreter", "shell")
          executionString = ""
          if scriptInterpreter == "shell"
            executionString = Builtins.sformat(
              "/bin/sh -x %1  2&> %2/%3.log",
              scriptPath,
              current_logdir,
              scriptName
            )
            SCR.Execute(path(".target.bash"), executionString)
          elsif scriptInterpreter == "perl"
            executionString = Builtins.sformat(
              "/usr/bin/perl %1  2&> %2/%3.log",
              scriptPath,
              current_logdir,
              scriptName
            )
            SCR.Execute(path(".target.bash"), executionString)
          elsif scriptInterpreter == "python"
            executionString = Builtins.sformat(
              "/usr/bin/python %1  2&> %2/%3.log",
              scriptPath,
              current_logdir,
              scriptName
            )
            SCR.Execute(path(".target.bash"), executionString)
          else
            Builtins.y2error("Unknown interpreter: %1", scriptInterpreter)
          end
          Builtins.y2milestone("Script Execution command: %1", executionString)
        end
        success = SCR.Execute(
          path(".target.bash"),
          Builtins.sformat(
            "cp %1 %2",
            Ops.get_string(file, "file_path", alternate_location),
            AutoinstConfig.files_dir
          )
        ) == 0
        counter = Ops.add(counter, 1)
      end
      success
    end

    publish variable: :modified, type: "boolean"
    publish function: :SetModified, type: "void ()"
    publish function: :GetModified, type: "boolean ()"
    publish variable: :Files, type: "list <map>"
    publish function: :Summary, type: "string ()"
    publish function: :Import, type: "boolean (list <map>)"
    publish function: :Export, type: "list <map> ()"
    publish function: :Write, type: "boolean ()"
  end

  AutoinstFile = AutoinstFileClass.new
  AutoinstFile.main
end
