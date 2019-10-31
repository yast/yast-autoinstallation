# encoding: utf-8

# File:  modules/AutoinstScripts.ycp
# Module:  Auto-Installation
# Summary:  Custom scripts
# Authors:  Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"

module Yast
  class AutoinstScriptsClass < Module
    include Yast::Logger

    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.import "Mode"
      Yast.import "AutoinstConfig"
      Yast.import "Summary"
      Yast.import "URL"
      Yast.import "Popup"
      Yast.import "Label"
      Yast.import "Report"

      Yast.include self, "autoinstall/io.rb"

      # Pre scripts
      @pre = []

      # Post scripts
      @post = []

      # Chroot scripts
      @chroot = []

      # Init scripts
      @init = []

      # postpart scripts
      @postpart = []

      # Merged scripts
      @merged = []

      # default value of settings modified
      @modified = false
      AutoinstScripts()
    end

    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      @modified = true

      nil
    end

    # Functions which returns if the settings were modified
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end

    # Checking if the script has the right format
    # @param tree [Hash] scripts section of the AutoYast configuration
    # @param key [String] kind of script (pre, post,..)
    # @return [Array<String>] of scripts
    def valid_scripts_for(tree, key)
      tree.fetch(key, []).select do |h|
        next true if h.is_a?(Hash)

        log.warn "Cannot evaluate #{key}: #{h.inspect}"
        false
      end
    end

    # merge all types of scripts into one single list
    # @return merged list
    def mergeScripts
      result = Builtins.maplist(@pre) do |p|
        p = Builtins.add(p, "type", "pre-scripts")
        deep_copy(p)
      end
      result = Convert.convert(
        Builtins.union(result, Builtins.maplist(@post) do |p|
          p = Builtins.add(p, "type", "post-scripts")
          deep_copy(p)
        end),
        from: "list",
        to:   "list <map>"
      )
      result = Convert.convert(
        Builtins.union(result, Builtins.maplist(@chroot) do |p|
          p = Builtins.add(p, "type", "chroot-scripts")
          deep_copy(p)
        end),
        from: "list",
        to:   "list <map>"
      )
      result = Convert.convert(
        Builtins.union(result, Builtins.maplist(@init) do |p|
          p = Builtins.add(p, "type", "init-scripts")
          deep_copy(p)
        end),
        from: "list",
        to:   "list <map>"
      )
      result = Convert.convert(
        Builtins.union(result, Builtins.maplist(@postpart) do |p|
          p = Builtins.add(p, "type", "postpartitioning-scripts")
          deep_copy(p)
        end),
        from: "list",
        to:   "list <map>"
      )
      deep_copy(result)
    end

    # Constructor
    def AutoinstScripts
      @merged = mergeScripts if !Mode.autoinst

      nil
    end

    # Dump the settings to a map, for autoinstallation use.
    # @return [Hash]
    def Export
      @pre = []
      @post = []
      @chroot = []
      @init = []
      @postpart = []
      Builtins.y2milestone("Merged %1", @merged)

      # split
      Builtins.foreach(@merged) do |s|
        if Ops.get_string(s, "type", "") == "pre-scripts"
          @pre = Builtins.add(@pre, s)
        elsif Ops.get_string(s, "type", "") == "post-scripts"
          @post = Builtins.add(@post, s)
        elsif Ops.get_string(s, "type", "") == "init-scripts"
          @init = Builtins.add(@init, s)
        elsif Ops.get_string(s, "type", "") == "chroot-scripts"
          @chroot = Builtins.add(@chroot, s)
        elsif Ops.get_string(s, "type", "") == "postpartitioning-scripts"
          @postpart = Builtins.add(@postpart, s)
        end
      end

      # clean
      expre = Builtins.maplist(@pre) do |p|
        {
          "filename"      => Ops.get_string(p, "filename", ""),
          "interpreter"   => Ops.get_string(p, "interpreter", ""),
          "source"        => Ops.get_string(p, "source", ""),
          "notification"  => Ops.get_string(p, "notification", ""),
          "location"      => Ops.get_string(p, "location", ""),
          "feedback"      => Ops.get_boolean(p, "feedback", false),
          "feedback_type" => Ops.get_string(p, "feedback_type", ""),
          "param-list"    => p.fetch("param-list", []),
          "debug"         => Ops.get_boolean(p, "debug", true)
        }
      end
      expost = Builtins.maplist(@post) do |p|
        {
          "filename"      => Ops.get_string(p, "filename", ""),
          "interpreter"   => Ops.get_string(p, "interpreter", ""),
          "source"        => Ops.get_string(p, "source", ""),
          "location"      => Ops.get_string(p, "location", ""),
          "notification"  => Ops.get_string(p, "notification", ""),
          "feedback"      => Ops.get_boolean(p, "feedback", false),
          "feedback_type" => Ops.get_string(p, "feedback_type", ""),
          "debug"         => Ops.get_boolean(p, "debug", true),
          "param-list"    => p.fetch("param-list", [])
        }
      end
      exchroot = Builtins.maplist(@chroot) do |p|
        {
          "filename"      => Ops.get_string(p, "filename", ""),
          "interpreter"   => Ops.get_string(p, "interpreter", ""),
          "source"        => Ops.get_string(p, "source", ""),
          "chrooted"      => Ops.get_boolean(p, "chrooted", false),
          "notification"  => Ops.get_string(p, "notification", ""),
          "location"      => Ops.get_string(p, "location", ""),
          "feedback"      => Ops.get_boolean(p, "feedback", false),
          "feedback_type" => Ops.get_string(p, "feedback_type", ""),
          "param-list"    => p.fetch("param-list", []),
          "debug"         => Ops.get_boolean(p, "debug", true)
        }
      end
      exinit = Builtins.maplist(@init) do |p|
        {
          "filename" => Ops.get_string(p, "filename", ""),
          "source"   => Ops.get_string(p, "source", ""),
          "location" => Ops.get_string(p, "location", ""),
          "debug"    => Ops.get_boolean(p, "debug", true)
        }
      end
      expostpart = Builtins.maplist(@postpart) do |p|
        {
          "filename"      => Ops.get_string(p, "filename", ""),
          "interpreter"   => Ops.get_string(p, "interpreter", ""),
          "source"        => Ops.get_string(p, "source", ""),
          "location"      => Ops.get_string(p, "location", ""),
          "notification"  => Ops.get_string(p, "notification", ""),
          "feedback"      => Ops.get_boolean(p, "feedback", false),
          "feedback_type" => Ops.get_string(p, "feedback_type", ""),
          "param-list"    => p.fetch("param-list", []),
          "debug"         => Ops.get_boolean(p, "debug", true)
        }
      end

      result = {}
      Ops.set(result, "pre-scripts", expre) if Ops.greater_than(Builtins.size(expre), 0)
      Ops.set(result, "post-scripts", expost) if Ops.greater_than(Builtins.size(expost), 0)
      Ops.set(result, "chroot-scripts", exchroot) if Ops.greater_than(Builtins.size(exchroot), 0)
      Ops.set(result, "init-scripts", exinit) if Ops.greater_than(Builtins.size(exinit), 0)
      if Ops.greater_than(Builtins.size(expostpart), 0)
        Ops.set(result, "postpartitioning-scripts", expostpart)
      end

      deep_copy(result)
    end

    def Resolve_ws(script)
      script = deep_copy(script)
      if !Builtins.isempty(Ops.get_string(script, "location", ""))
        l = Ops.get_string(script, "location", "").strip
        if l != Ops.get_string(script, "location", "")
          Builtins.y2milestone(
            "changed script location to \"%1\" from \"%2\"",
            l,
            Ops.get_string(script, "location", "")
          )
          Ops.set(script, "location", l)
        end
      end
      deep_copy(script)
    end

    def Resolve_relurl(script)
      script = deep_copy(script)
      if Builtins.issubstring(
        Ops.get_string(script, "location", ""),
        "relurl://"
      )
        l = Ops.get_string(script, "location", "")
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
        Ops.set(script, "location", newloc)
        Builtins.y2milestone("changed relurl to %1 for script", newloc)
      end
      deep_copy(script)
    end

    def Resolve_location(d)
      d = deep_copy(d)
      d = Builtins.maplist(d) { |script| Resolve_relurl(Resolve_ws(script)) }
      deep_copy(d)
    end

    # Get all the configuration from a map.
    # When called by autoinst_<module name> (preparing autoinstallation data)
    # the map may be empty.
    # @param s [Hash] scripts section from an AutoYaST profile
    # @return [Boolean]
    def Import(s)
      s = deep_copy(s)
      Builtins.y2debug("Calling AutoinstScripts::Import()")
      # take only hash entries (bnc#986049)
      @pre = valid_scripts_for(s, "pre-scripts")
      @init = valid_scripts_for(s, "init-scripts")
      @post = valid_scripts_for(s, "post-scripts")
      @chroot = valid_scripts_for(s, "chroot-scripts")
      @postpart = valid_scripts_for(s, "postpartitioning-scripts")

      @pre = Resolve_location(@pre)
      @init = Resolve_location(@init)
      @post = Resolve_location(@post)
      @chroot = Resolve_location(@chroot)
      @postpart = Resolve_location(@postpart)

      @merged = mergeScripts
      Builtins.y2debug("merged: %1", @merged)
      true
    end

    # Return Summary
    # @return [String] summary
    def Summary
      summary = ""
      summary = Summary.AddHeader(summary, _("Preinstallation Scripts"))
      if Ops.greater_than(Builtins.size(@pre), 0)
        summary = Summary.OpenList(summary)
        Builtins.foreach(@pre) do |script|
          summary = Summary.AddListItem(
            summary,
            Ops.get_string(script, "filename", "")
          )
        end
        summary = Summary.CloseList(summary)
      else
        summary = Summary.AddLine(summary, Summary.NotConfigured)
      end
      summary = Summary.AddHeader(summary, _("Postinstallation Scripts"))
      if Ops.greater_than(Builtins.size(@post), 0)
        summary = Summary.OpenList(summary)
        Builtins.foreach(@post) do |script|
          summary = Summary.AddListItem(
            summary,
            Ops.get_string(script, "filename", "")
          )
        end
        summary = Summary.CloseList(summary)
      else
        summary = Summary.AddLine(summary, Summary.NotConfigured)
      end
      summary = Summary.AddHeader(summary, _("Chroot Scripts"))
      if Ops.greater_than(Builtins.size(@chroot), 0)
        summary = Summary.OpenList(summary)
        Builtins.foreach(@chroot) do |script|
          summary = Summary.AddListItem(
            summary,
            Ops.get_string(script, "filename", "")
          )
        end
        summary = Summary.CloseList(summary)
      else
        summary = Summary.AddLine(summary, Summary.NotConfigured)
      end
      summary = Summary.AddHeader(summary, _("Init Scripts"))
      if Ops.greater_than(Builtins.size(@init), 0)
        summary = Summary.OpenList(summary)
        Builtins.foreach(@init) do |script|
          summary = Summary.AddListItem(
            summary,
            Ops.get_string(script, "filename", "")
          )
        end
        summary = Summary.CloseList(summary)
      else
        summary = Summary.AddLine(summary, Summary.NotConfigured)
      end
      summary = Summary.AddHeader(summary, _("Postpartitioning Scripts"))
      if Ops.greater_than(Builtins.size(@postpart), 0)
        summary = Summary.OpenList(summary)
        Builtins.foreach(@postpart) do |script|
          summary = Summary.AddListItem(
            summary,
            Ops.get_string(script, "filename", "")
          )
        end
        summary = Summary.CloseList(summary)
      else
        summary = Summary.AddLine(summary, Summary.NotConfigured)
      end
      summary
    end

    # delete a script from a list
    # @param scriptName [String] script name
    # @return [void]
    def deleteScript(scriptName)
      clean = Builtins.filter(@merged) do |s|
        Ops.get_string(s, "filename", "") != scriptName
      end
      @merged = deep_copy(clean)
      nil
    end

    # Add or edit a script
    # @param [String] scriptName script name
    # @param [String] source source of script
    # @param [String] interpreter interpreter to be used with script
    # @param [String] type type of script
    # @return [void]
    def AddEditScript(scriptName, source, interpreter, type, chrooted, debug,
      feedback, feedback_type, location, notification)
      mod = false
      @merged = Builtins.maplist(@merged) do |script|
        # Edit
        if Ops.get_string(script, "filename", "") == scriptName
          oldScript = {}
          oldScript = Builtins.add(oldScript, "filename", scriptName)
          oldScript = Builtins.add(oldScript, "source", source)
          oldScript = Builtins.add(oldScript, "interpreter", interpreter)
          oldScript = Builtins.add(oldScript, "type", type)
          oldScript = Builtins.add(oldScript, "chrooted", chrooted)
          oldScript = Builtins.add(oldScript, "debug", debug)
          oldScript = Builtins.add(oldScript, "feedback", feedback)
          oldScript = Builtins.add(oldScript, "feedback_type", feedback_type)
          oldScript = Builtins.add(oldScript, "location", location)
          oldScript = Builtins.add(oldScript, "notification", notification)

          mod = true
          next deep_copy(oldScript)
        else
          next deep_copy(script)
        end
      end

      if !mod
        script = {}
        script = Builtins.add(script, "filename", scriptName)
        script = Builtins.add(script, "source", source)
        script = Builtins.add(script, "interpreter", interpreter)
        script = Builtins.add(script, "type", type)
        script = Builtins.add(script, "chrooted", chrooted)
        script = Builtins.add(script, "debug", debug)
        script = Builtins.add(script, "feedback", feedback)
        script = Builtins.add(script, "feedback_type", feedback_type)
        script = Builtins.add(script, "location", location)
        script = Builtins.add(script, "notification", notification)

        @merged = Builtins.add(@merged, script)
      end
      Builtins.y2debug("Merged scripts: %1", @merged)
      nil
    end

    # return type of script as formatted string
    # @param type [String] script type
    # @return [String] type as translated string
    def typeString(type)
      if type == "pre-scripts"
        return _("Pre")
      elsif type == "post-scripts"
        return _("Post")
      elsif type == "init-scripts"
        return _("Init")
      elsif type == "chroot-scripts"
        return _("Chroot")
      elsif type == "postpartitioning-scripts"
        return _("Postpartitioning")
      end

      _("Unknown")
    end

    # bidirectional feedback during script execution
    # Experimental

    def splitParams(s)
      l = Builtins.splitstring(s, "|")
      ret = {}
      l = Builtins.remove(l, 0)
      Builtins.foreach(l) do |element|
        p = Builtins.splitstring(element, "=")
        Ops.set(ret, Ops.get(p, 0, ""), Ops.get(p, 1, ""))
      end
      deep_copy(ret)
    end

    def interactiveScript(shell, debug, scriptPath, params, current_logdir, scriptName)
      data = {}
      widget = ""
      SCR.Execute(path(".target.remove"), "/tmp/ay_opipe")
      SCR.Execute(path(".target.remove"), "/tmp/ay_ipipe")
      SCR.Execute(path(".target.bash"), "mkfifo -m 660 /tmp/ay_opipe", {})
      SCR.Execute(path(".target.bash"), "mkfifo -m 660 /tmp/ay_ipipe", {})
      execute = Builtins.sformat(
        "%1 %2 %3 %4 2> %5/%6.log ",
        shell,
        debug,
        scriptPath,
        params,
        current_logdir,
        scriptName
      )
      SCR.Execute(
        path(".target.bash_background"),
        Ops.add("OPIPE=/tmp/ay_opipe IPIPE=/tmp/ay_ipipe ", execute),
        {}
      )
      run = true
      ok_button = false
      vbox = VBox()

      buffer = []
      while SCR.Read(path(".target.lstat"), "/tmp/ay_opipe") != {} && run
        data = Convert.to_map(
          SCR.Execute(path(".target.bash_output"), "cat /tmp/ay_opipe", {})
        )
        buffer = Builtins.splitstring(Ops.get_string(data, "stdout", ""), "\n")
        while buffer != []
          line = Ops.get(buffer, 0, "")
          buffer = Builtins.remove(buffer, 0)
          next if Builtins.size(line) == 0

          Ops.set(data, "stdout", line)
          Builtins.y2milestone("working on line %1", line)
          if Builtins.substring(Ops.get_string(data, "stdout", ""), 0, 8) == "__EXIT__"
            if widget == "radiobutton"
              vbox = Builtins.add(vbox, PushButton(Id(:ok), Label.OKButton))
              UI.OpenDialog(RadioButtonGroup(Id(:rb), vbox))
            end
            if ok_button == true
              UI.ChangeWidget(Id(:ok), :Enabled, true)
              ret = UI.UserInput
              if widget == "radiobutton"
                val = UI.QueryWidget(Id(:rb), :CurrentButton)
                SCR.Execute(
                  path(".target.bash"),
                  Builtins.sformat(
                    "echo \"%1\" > /tmp/ay_ipipe",
                    AutoinstConfig.ShellEscape(Convert.to_string(val))
                  ),
                  {}
                )
              elsif widget == "entry"
                val = UI.QueryWidget(Id(:ay_entry), :Value)
                SCR.Execute(
                  path(".target.bash"),
                  Builtins.sformat(
                    "echo \"%1\" > /tmp/ay_ipipe",
                    AutoinstConfig.ShellEscape(Convert.to_string(val))
                  ),
                  {}
                )
              end
              ok_button = false
            end
            vbox = VBox()
            if widget == ""
              run = false
            else
              UI.CloseDialog
            end
            widget = ""
          elsif Builtins.substring(Ops.get_string(data, "stdout", ""), 0, 12) == "__PROGRESS__"
            params = splitParams(Ops.get_string(data, "stdout", ""))
            UI.OpenDialog(
              VBox(
                ProgressBar(
                  Id(:pr),
                  Ops.get(params, "label", ""),
                  Builtins.tointeger(Ops.get(params, "max", "100")),
                  0
                )
              )
            )
            widget = "progressbar"
          elsif Builtins.substring(Ops.get_string(data, "stdout", ""), 0, 8) == "__TEXT__"
            params = splitParams(Ops.get_string(data, "stdout", ""))
            hspace = Builtins.tointeger(Ops.get(params, "width", "10"))
            vspace = Builtins.tointeger(Ops.get(params, "height", "20"))
            ok_button = Builtins.haskey(params, "okbutton") ? true : false
            vbox = VBox(
              HSpacing(hspace),
              HBox(VSpacing(vspace), RichText(Id(:mle), ""))
            )
            vbox = Builtins.add(vbox, PushButton(Id(:ok), Label.OKButton)) if ok_button == true
            UI.OpenDialog(vbox)
            UI.ChangeWidget(Id(:ok), :Enabled, false) if ok_button == true
            widget = "text"
          elsif Builtins.substring(Ops.get_string(data, "stdout", ""), 0, 9) == "__ENTRY__"
            params = splitParams(Ops.get_string(data, "stdout", ""))
            if Builtins.haskey(params, "description")
              vbox = Builtins.add(vbox, HSpacing(40))
              vbox = Builtins.add(
                vbox,
                RichText(Ops.get(params, "description", ""))
              )
            end
            vbox = Builtins.add(
              vbox,
              TextEntry(
                Id(:ay_entry),
                Ops.get(params, "label", ""),
                Ops.get(params, "default", "")
              )
            )
            vbox = Builtins.add(vbox, PushButton(Id(:ok), Label.OKButton))
            UI.OpenDialog(vbox)
            widget = "entry"
            ok_button = true
          elsif Builtins.substring(Ops.get_string(data, "stdout", ""), 0, 15) == "__RADIOBUTTON__"
            params = splitParams(Ops.get_string(data, "stdout", ""))
            if Builtins.haskey(params, "description")
              vbox = Builtins.add(vbox, HSpacing(60))
              vbox = Builtins.add(
                vbox,
                RichText(Ops.get(params, "description", ""))
              )
            end
            widget = "radiobutton"
            ok_button = true
          else
            if widget == "progressbar"
              UI.ChangeWidget(
                Id(:pr),
                :Value,
                Builtins.tointeger(Ops.get_string(data, "stdout", "0"))
              )
            elsif widget == "text"
              UI.ChangeWidget(
                Id(:mle),
                :Value,
                Ops.add(
                  Convert.to_string(UI.QueryWidget(Id(:mle), :Value)),
                  Ops.get_string(data, "stdout", "")
                )
              )
            elsif widget == "radiobutton"
              if Builtins.substring(Ops.get_string(data, "stdout", ""), 0, 10) == "__BUTTON__"
                params = splitParams(Ops.get_string(data, "stdout", ""))
                vbox = Builtins.add(
                  vbox,
                  Left(
                    RadioButton(
                      Id(Ops.get(params, "val", "")),
                      Ops.get(params, "label", "")
                    )
                  )
                )
              else
                Builtins.y2milestone(
                  "*urgs* received '%1' instead of '__BUTTON__' during RADIOBUTTON creation",
                  Ops.get_string(data, "stdout", "")
                )
              end
            end
          end
        end
      end
      SCR.Execute(path(".target.remove"), "/tmp/ay_opipe")
      SCR.Execute(path(".target.remove"), "/tmp/ay_ipipe")

      nil
    end

    # Execute pre scripts
    # @param type [String] type of script
    # @param special [Boolean] if script should be executed in chroot env.
    # @return [Boolean] true on success
    def Write(type, special)
      return true if !Mode.autoinst && !Mode.autoupgrade

      scripts = []
      if type == "pre-scripts"
        scripts = deep_copy(@pre)
      elsif type == "init-scripts"
        scripts = deep_copy(@init)
      elsif type == "chroot-scripts" && !special
        scripts = Builtins.filter(@chroot) do |s|
          !Ops.get_boolean(s, "chrooted", false)
        end
      elsif type == "chroot-scripts" && special
        scripts = Builtins.filter(@chroot) do |s|
          Ops.get_boolean(s, "chrooted", false)
        end
      elsif type == "post-scripts"
        scripts = deep_copy(@post)
      elsif type == "postpartitioning-scripts"
        scripts = deep_copy(@postpart)
      else
        Builtins.y2error("Unsupported script type")
        return false
      end

      tmpdirString = ""
      current_logdir = ""

      if type == "pre-scripts" || type == "postpartitioning-scripts"
        tmpdirString = Builtins.sformat("%1/%2", AutoinstConfig.tmpDir, type)
        SCR.Execute(path(".target.mkdir"), tmpdirString)

        current_logdir = Builtins.sformat("%1/logs", tmpdirString)
        SCR.Execute(path(".target.mkdir"), current_logdir)
      elsif type == "chroot-scripts"
        if !special
          tmpdirString = Builtins.sformat(
            "%1%2",
            AutoinstConfig.destdir,
            AutoinstConfig.scripts_dir
          )
          SCR.Execute(path(".target.mkdir"), tmpdirString)

          current_logdir = Builtins.sformat(
            "%1%2",
            AutoinstConfig.destdir,
            AutoinstConfig.logs_dir
          )
          SCR.Execute(path(".target.mkdir"), current_logdir)
        else
          tmpdirString = Builtins.sformat("%1", AutoinstConfig.scripts_dir)
          SCR.Execute(path(".target.mkdir"), tmpdirString)

          current_logdir = Builtins.sformat("%1", AutoinstConfig.logs_dir)
          SCR.Execute(path(".target.mkdir"), current_logdir)
        end
      else
        current_logdir = AutoinstConfig.logs_dir
      end

      Builtins.foreach(scripts) do |s|
        scriptInterpreter = Ops.get_string(s, "interpreter", "shell")
        params = s.fetch("param-list", []).join(" ")
        scriptName = Ops.get_string(s, "filename", "")
        if scriptName == ""
          t = URL.Parse(Ops.get_string(s, "location", ""))
          scriptName = basename(Ops.get_string(t, "path", ""))
          scriptName = type if scriptName == ""
        end
        scriptPath = ""
        if type == "pre-scripts" || type == "postpartitioning-scripts"
          scriptPath = Builtins.sformat(
            "%1/%2/%3",
            AutoinstConfig.tmpDir,
            type,
            scriptName
          )
          Builtins.y2milestone("Writing %1 script into %2", type, scriptPath)
          if Ops.get_string(s, "location", "") != ""
            Builtins.y2debug(
              "getting script: %1",
              Ops.get_string(s, "location", "")
            )
            if !GetURL(Ops.get_string(s, "location", ""), scriptPath)
              Builtins.y2error(
                "script %1 could not be retrieved",
                Ops.get_string(s, "location", "")
              )
            end
          else
            SCR.Write(
              path(".target.string"),
              scriptPath,
              Ops.get_string(s, "source", "echo Empty script!")
            )
          end
        elsif type == "init-scripts"
          scriptPath = Builtins.sformat(
            "%1/%2",
            AutoinstConfig.initscripts_dir,
            scriptName
          )
          if Ops.get_string(s, "location", "") != ""
            scriptPath = AutoinstConfig.destdir + scriptPath # bnc961320
            Builtins.y2debug(
              "getting script: %1",
              Ops.get_string(s, "location", "")
            )
            if !GetURL(Ops.get_string(s, "location", ""), scriptPath)
              Builtins.y2error(
                "script %1 could not be retrieved",
                Ops.get_string(s, "location", "")
              )
            end
          else
            SCR.Write(
              path(".target.string"),
              scriptPath,
              Ops.get_string(s, "source", "echo Empty script!")
            )
          end
          Builtins.y2milestone("Writing init script into %1", scriptPath)
          # moved to 1st stage because of systemd
          # Service::Enable("autoyast");
        elsif type == "chroot-scripts"
          toks = URL.Parse(Ops.get_string(s, "location", ""))
          # special == true ---> The script has to be installed into /mnt
          # because it will be called in a chroot environment.
          # (bnc#889931)
          # Add /mnt only if the script is getting via GetURL.
          # In the other case SCR will do it via target setting.
          # (bnc#897212)
          #
          # FIXME: Find out why "nfs" has a special behavior.
          #        Take another name for "s"
          scriptPath = if (special && s["location"] && !s["location"].empty?) ||
              toks["scheme"] == "nfs"

            Builtins.sformat(
              "%1%2/%3",
              AutoinstConfig.destdir,
              AutoinstConfig.scripts_dir,
              scriptName
            )
          else
            Builtins.sformat(
              "%1/%2",
              AutoinstConfig.scripts_dir,
              scriptName
            )
          end

          Builtins.y2milestone("Writing chroot script into %1", scriptPath)
          if Ops.get_string(s, "location", "") != ""
            if !GetURL(Ops.get_string(s, "location", ""), scriptPath)
              Builtins.y2error(
                "script %1 could not be retrieved",
                Ops.get_string(s, "location", "")
              )
            end
          else
            SCR.Write(
              path(".target.string"),
              scriptPath,
              Ops.get_string(s, "source", "echo Empty script!")
            )
          end
          # FIXME: That's duplicate code
          if (special && s["location"] && !s["location"].empty?) ||
              toks["scheme"] == "nfs"
            # cut off the e.g. /mnt for later execution
            scriptPath = scriptPath[AutoinstConfig.destdir.length..-1]
          end
        else
          scriptPath = Builtins.sformat(
            "%1/%2",
            AutoinstConfig.scripts_dir,
            scriptName
          )
          if Ops.get_string(s, "location", "") != ""
            if special # downloading scripts for post-installation
              scriptPath = AutoinstConfig.destdir + scriptPath
              if !GetURL(Ops.get_string(s, "location", ""), scriptPath)
                Builtins.y2error(
                  "script %1 could not be retrieved",
                  Ops.get_string(s, "location", "")
                )
              else
                log.info("Script downlaoded to #{scriptPath}")
              end
            else
              log.info("Using already downlaoded script #{scriptPath}")
            end
          else
            log.info("Writing script into #{scriptPath}")
            SCR.Write(
              path(".target.string"),
              scriptPath,
              Ops.get_string(s, "source", "echo Empty script!")
            )
          end
        end
        if type != "init-scripts" &&
            !(type == "post-scripts" && special) # We are not in the first installation stage
          # where post-scripts have been downloaded only.
          # string message =  sformat(_("Executing user supplied script: %1"), scriptName);
          executionString = ""
          showFeedback = Ops.get_boolean(s, "feedback", false)

          if Ops.get_string(s, "notification", "") != ""
            Popup.ShowFeedback("", Ops.get_string(s, "notification", ""))
          end

          if scriptInterpreter == "shell"
            debug = Ops.get_boolean(s, "debug", true) ? "-x" : ""
            if SCR.Read(path(".target.size"), Ops.add(scriptPath, "-run")) == -1 ||
                Ops.get_boolean(s, "rerun", false) == true
              if Ops.get_boolean(s, "interactive", false) == true
                interactiveScript(
                  "/bin/sh",
                  debug,
                  scriptPath,
                  params,
                  current_logdir,
                  scriptName
                )
              else
                executionString = Builtins.sformat(
                  "/bin/sh %1 %2 %3 &> %4/%5.log ",
                  debug,
                  scriptPath,
                  params,
                  current_logdir,
                  scriptName
                )
                Builtins.y2milestone(
                  "Script Execution command: %1",
                  executionString
                )
                SCR.Execute(path(".target.bash"), executionString)
                SCR.Execute(
                  path(".target.bash"),
                  "/bin/touch $FILE",
                  "FILE" => Ops.add(scriptPath, "-run")
                )
              end
            end
          elsif scriptInterpreter == "perl"
            debug = Ops.get_boolean(s, "debug", true) ? "-w" : ""
            if SCR.Read(path(".target.size"), Ops.add(scriptPath, "-run")) == -1 ||
                Ops.get_boolean(s, "rerun", false) == true
              if Ops.get_boolean(s, "interactive", false) == true
                interactiveScript(
                  "/usr/bin/perl",
                  debug,
                  scriptPath,
                  params,
                  current_logdir,
                  scriptName
                )
              else
                executionString = Builtins.sformat(
                  "/usr/bin/perl %1 %2 %3 &> %4/%5.log ",
                  debug,
                  scriptPath,
                  params,
                  current_logdir,
                  scriptName
                )
                Builtins.y2milestone(
                  "Script Execution command: %1",
                  executionString
                )
                SCR.Execute(path(".target.bash"), executionString)
                SCR.Execute(
                  path(".target.bash"),
                  "/bin/touch $FILE",
                  "FILE" => Ops.add(scriptPath, "-run")
                )
              end
            end
          elsif scriptInterpreter == "python"
            if SCR.Read(path(".target.size"), Ops.add(scriptPath, "-run")) == -1 ||
                Ops.get_boolean(s, "rerun", false) == true
              if Ops.get_boolean(s, "interactive", false) == true
                interactiveScript(
                  "/usr/bin/python",
                  "",
                  scriptPath,
                  params,
                  current_logdir,
                  scriptName
                )
              else
                executionString = Builtins.sformat(
                  "/usr/bin/python %1 %2 &> %3/%4.log ",
                  scriptPath,
                  params,
                  current_logdir,
                  scriptName
                )
                Builtins.y2milestone(
                  "Script Execution command: %1",
                  executionString
                )
                SCR.Execute(path(".target.bash"), executionString)
                SCR.Execute(
                  path(".target.bash"),
                  "/bin/touch $FILE",
                  "FILE" => Ops.add(scriptPath, "-run")
                )
              end
            end
          else
            Builtins.y2error("Unknown interpreter: %1", scriptInterpreter)
          end
          feedback = ""

          Popup.ClearFeedback if Ops.get_string(s, "notification", "") != ""

          if executionString != ""
            if showFeedback
              feedback = Convert.to_string(
                SCR.Read(
                  path(".target.string"),
                  Ops.add(
                    Ops.add(Ops.add(current_logdir, "/"), scriptName),
                    ".log"
                  )
                )
              )
            end
            if Ops.greater_than(Builtins.size(feedback), 0)
              if Ops.get_string(s, "feedback_type", "") == ""
                Popup.LongText("", RichText(Opt(:plainText), feedback), 50, 20)
              elsif Ops.get_string(s, "feedback_type", "") == "message"
                Report.Message(feedback)
              elsif Ops.get_string(s, "feedback_type", "") == "warning"
                Report.Warning(feedback)
              elsif Ops.get_string(s, "feedback_type", "") == "error"
                Report.Error(feedback)
              end
            end
          end
        end
      end

      true
    end

    publish variable: :pre, type: "list <map>"
    publish variable: :post, type: "list <map>"
    publish variable: :chroot, type: "list <map>"
    publish variable: :init, type: "list <map>"
    publish variable: :postpart, type: "list <map>"
    publish variable: :merged, type: "list <map>"
    publish variable: :modified, type: "boolean"
    publish function: :SetModified, type: "void ()"
    publish function: :GetModified, type: "boolean ()"
    publish function: :Export, type: "map <string, list> ()"
    publish function: :Resolve_ws, type: "map (map)"
    publish function: :Resolve_relurl, type: "map (map)"
    publish function: :Resolve_location, type: "list <map> (list <map>)"
    publish function: :Import, type: "boolean (map)"
    publish function: :Summary, type: "string ()"
    publish function: :deleteScript, type: "void (string)"
    publish function: :AddEditScript,
            type:     "void (string, string, string, string, boolean, boolean, " \
      "boolean, boolean, string, string, string)"
    publish function: :typeString, type: "string (string)"
    publish function: :Write, type: "boolean (string, boolean)"
  end

  AutoinstScripts = AutoinstScriptsClass.new
  AutoinstScripts.main
end
