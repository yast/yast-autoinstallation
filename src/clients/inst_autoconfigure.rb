# File:  clients/inst_autoconfigure.ycp
# Package:  Auto-installation
# Author:      Anas Nashif <nashif@suse.de>
# Summary:  This module finishes auto-installation and configures
#    the system as described in the profile file.
#
# $Id$

require "yast2/system_time"

module Yast
  class InstAutoconfigureClient < Client
    include Yast::Logger

    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.import "Profile"
      Yast.import "AutoinstScripts"
      Yast.import "AutoinstConfig"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "Call"
      Yast.import "Y2ModuleConfig"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Report"

      @current_step = 0 # Required by logStep()

      @resource = ""
      @module_auto = ""

      # Help text for last dialog of base installation
      @help_text = _(
        "<p>\n" \
          "Please wait while the system is being configured.\n" \
          "</p>"
      )

      Builtins.y2milestone(
        "Profile general,mode:%1",
        Ops.get_map(Profile.current, ["general", "mode"], {})
      )
      @need_systemd_isolate = Ops.get_boolean(
        Profile.current, ["general", "mode", "activate_systemd_default_target"], true
      )
      final_restart_services = Ops.get_boolean(
        Profile.current, ["general", "mode", "final_restart_services"], true
      )
      @max_steps = Y2ModuleConfig.ModuleMap.size + 3 # additional for scripting and finished message
      @max_steps = Ops.add(@max_steps, 1) if @need_systemd_isolate
      @max_steps += 1 if final_restart_services
      Builtins.y2milestone(
        "max steps: %1 need_isolate:%2",
        @max_steps,
        @need_systemd_isolate
      )
      @contents = VBox(
        LogView(Id(:log), "", 10, 0),
        # Progress bar that displays overall progress in this dialog
        ProgressBar(Id(:progress), _("Progress"), @max_steps, 0)
      )

      Wizard.SetNextButton(:next, Label.NextButton)
      Wizard.SetBackButton(:back, Label.BackButton)
      Wizard.SetAbortButton(:abort, Label.AbortButton)

      Wizard.SetContents(
        # Dialog title for autoyast dialog
        _("Configuring System according to auto-install settings"),
        @contents,
        @help_text,
        false,
        false
      )

      Wizard.DisableAbortButton

      Builtins.y2debug("Module map: %1", Y2ModuleConfig.ModuleMap)
      Builtins.y2debug("Current profile: %1", Profile.current)

      # Report only those that are 'not unsupported', these were already reported
      # Unsupported sections have already been reported in the first stage
      unsupported_sections = Y2ModuleConfig.unsupported_profile_sections
      unknown_sections = Y2ModuleConfig.unhandled_profile_sections - unsupported_sections
      if unknown_sections.any?
        log.error "Could not process these unknown profile sections: #{unknown_sections}"
        needed_packages = Y2ModuleConfig.required_packages(unknown_sections)
        schema_package_list = if needed_packages.empty?
          unknown_sections.map { |section| "&lt;#{section}/&gt;" }
        else
          needed_packages.map do |section, packages|
            package_description = case packages.size
            when 0
              _("No needed package found.")
            when 1
              # TRANSLATOR: %s is the package name
              _("Needed package: %s") % packages.first
            else
              # TRANSLATOR: %s is the list of package names
              _("Needed packages: %s") % packages.join(",")
            end

            "&lt;#{section}/&gt; - #{package_description}"
          end
        end

        Report.LongWarning(
          # TRANSLATORS: Error message, %s is replaced by newline-separated
          # list of unknown sections of the profile
          # Do not translate words in brackets
          _(
            "These sections of the AutoYaST profile cannot be processed on this " \
            "system:<br><br>%s<br><br>" \
            "Maybe they were misspelled or your profile does not contain " \
            "all the needed YaST packages in the &lt;software/&gt; section " \
            "as required for functionality provided by additional modules."
          ) %
            schema_package_list.join("<br>")
        )
      end

      @deps = Y2ModuleConfig.Deps

      Builtins.y2milestone("Order: %1", Builtins.maplist(@deps) do |d|
        Ops.get_string(d, "res", "")
      end)

      Builtins.foreach(@deps) do |r|
        p = Ops.get_string(r, "res", "")
        d = Ops.get_map(r, "data", {})
        if Ops.get_string(d, "X-SuSE-YaST-AutoInst", "") == "all" ||
            Ops.get_string(d, "X-SuSE-YaST-AutoInst", "") == "write"
          @resource = if Builtins.haskey(d, Yast::Y2ModuleConfigClass::RESOURCE_NAME_KEY) &&
              Ops.get_string(d, Yast::Y2ModuleConfigClass::RESOURCE_NAME_KEY, "") != ""
            Ops.get_string(
              d,
              Yast::Y2ModuleConfigClass::RESOURCE_NAME_KEY,
              "unknown"
            )
          else
            p
          end
          Builtins.y2milestone("current resource: %1", @resource)

          # determine name of client, if not use default name
          @module_auto = if Builtins.haskey(d, "X-SuSE-YaST-AutoInstClient")
            Ops.get_string(
              d,
              "X-SuSE-YaST-AutoInstClient",
              "none"
            )
          else
            Builtins.sformat("%1_auto", p)
          end

          result = {}
          if Builtins.haskey(Profile.current, @resource)
            Builtins.y2milestone("Writing configuration for %1", p)
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
                logStep(Builtins.sformat(_("Configuring %1"), p))
              else
                logStep(Builtins.sformat(_("Not Configuring %1"), p))
              end

              processWait(p, "pre-modules")
              Call.Function(@module_auto, ["Import", Builtins.eval(result)])
              Call.Function(@module_auto, ["Write"])
              processWait(p, "post-modules")
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
                logStep(Builtins.sformat(_("Configuring %1"), p))
              else
                logStep(Builtins.sformat(_("Not Configuring %1"), p))
              end
              # Call::Function(module_auto, ["Import", eval(Profile::current[resource]:$[])   ]);
              processWait(@resource, "pre-modules")
              Call.Function(@module_auto, ["Write"])
              processWait(@resource, "post-modules")
            else
              if Ops.greater_than(
                Builtins.size(Ops.get_list(Profile.current, @resource, [])),
                0
              )
                logStep(Builtins.sformat(_("Configuring %1"), p))
              else
                logStep(Builtins.sformat(_("Not Configuring %1"), p))
              end
              if Ops.get_string(d, "X-SuSE-YaST-AutoLogResource", "true") == "true"
                Builtins.y2milestone(
                  "Calling auto client with: %1",
                  Builtins.eval(Ops.get_list(Profile.current, @resource, []))
                )
              else
                Builtins.y2milestone(
                  "logging for resource %1 turned off",
                  @resource
                )
                Builtins.y2debug(
                  "Calling auto client with: %1",
                  Builtins.eval(Ops.get_list(Profile.current, @resource, []))
                )
              end
              # Call::Function(module_auto, ["Import",  eval(Profile::current[resource]:[]) ]);
              processWait(@resource, "pre-modules")
              Call.Function(@module_auto, ["Write"])
              processWait(@resource, "post-modules")
            end
          else
            @current_step = Ops.add(@current_step, 1)
            UI.ChangeWidget(Id(:progress), :Value, @current_step)
          end
        else
          @current_step = Ops.add(@current_step, 1)
          UI.ChangeWidget(Id(:progress), :Value, @current_step)
        end
      end

      # Initialize scripts stack
      AutoinstScripts.Import(Profile.current.fetch("scripts", {}))

      # online update
      if Ops.get_boolean(
        Profile.current,
        ["software", "do_online_update"],
        false
      ) == true
        processWait("do_online_update", "pre-modules")
        @online_update_ret = Convert.to_symbol(
          Call.Function("do_online_update_auto", ["Write"])
        )
        processWait("do_online_update", "post-modules")
        if @online_update_ret == :reboot
          # AddEditScript(scriptName, source, interpreter, type, chrooted, debug, feedback, feedback_type, location, notification)
          AutoinstScripts.AddEditScript("zzz_reboot", "shutdown -r now", "shell", "init",
            false, false, false, "", "", "") # wonderful API without defaults
        end
      end

      logStep(_("Executing Post-Scripts"))
      AutoinstScripts.Write("post-scripts", false)

      logStep(_("Writing Init-Scripts"))
      AutoinstScripts.Write("init-scripts", false)

      @max_wait = Ops.get_integer(
        Profile.current,
        ["general", "mode", "max_systemd_wait"],
        30
      )

      @ser_ignore = [
        "YaST2-Second-Stage.service",
        "autoyast-initscripts.service",
        # Do not restart dbus. Otherwise some services will hang.
        # bnc#937900
        "dbus.service",
        # Do not restart wickedd* services
        # bnc#944349
        "^wickedd",
        # Do not restart NetworkManager* services
        # bnc#955260
        "^NetworkManager"
      ]

      if final_restart_services
        logStep(_("Restarting all running services"))
        @cmd = "systemctl --type=service list-units | grep \" running \""
        @out = Convert.to_map(SCR.Execute(path(".target.bash_output"), @cmd))
        @sl = Ops.get_string(@out, "stdout", "").split("\n").collect { |c| c.split(" ").first }
        Builtins.y2milestone("running services \"%1\"", @sl)

        # Filtering out all services which must not to be restarted
        @sl.reject! { |s| @ser_ignore.any? { |i| s.match(/#{i}/) } }

        Builtins.y2milestone("restarting services \"%1\"", @sl)
        @cmd = Ops.add(
          "systemctl --no-block restart ",
          Builtins.mergestring(@sl, " ")
        )
        Builtins.y2milestone("before calling \"%1\"", @cmd)
        @out = Convert.to_map(SCR.Execute(path(".target.bash_output"), @cmd))
        Builtins.y2milestone("after  calling \"%1\"", @cmd)
        wait_systemd_finished(@max_wait, @ser_ignore)
      else
        Builtins.y2milestone("Do not restart all services (defined in autoyast.xml)")
      end
      if @need_systemd_isolate
        logStep(_("Activating systemd default target"))
        @cmd = "systemctl --no-block --ignore-dependencies isolate default.target"
        Builtins.y2milestone("before calling \"%1\"", @cmd)
        @out = Convert.to_map(SCR.Execute(path(".target.bash_output"), @cmd))
        Builtins.y2milestone("after  calling \"%1\"", @cmd)
        Builtins.y2milestone("ret=%1", @out)
        wait_systemd_finished(@max_wait, @ser_ignore)
      else
        Builtins.y2milestone("Do not activate systemd default target (defined in autoyast.xml)")
      end

      # Just in case, remove this file to avoid reconfiguring...
      SCR.Execute(path(".target.remove"), "/var/lib/YaST2/runme_at_boot")

      logStep(_("Finishing Configuration"))

      # Invoke SnapshotsFinish client to perform snapshots (if needed)
      WFM.CallFunction("snapshots_finish", ["Write"])

      # Disabling all local repos
      WFM.CallFunction("pkg_finish", ["Write"])

      # Saving y2logs
      WFM.CallFunction("save_y2logs")

      :next
    end

    # Display a step in the LogView widget and increment the progress bar.
    # Uses global variable 'current_step'.
    #
    # @param [String] step_descr description of the step.
    def logStep(step_descr)
      @current_step = Ops.add(@current_step, 1)
      UI.ChangeWidget(Id(:progress), :Value, @current_step)
      UI.ChangeWidget(Id(:log), :LastLine, Ops.add(step_descr, "\n"))
      Builtins.y2milestone(
        "current step: %1 desc:%2",
        @current_step,
        step_descr
      )
      nil
    end

    def MatchInterface(id)
      ret = id
      if Builtins.substring(id, 0, 7) == "eth-id-"
        ls = Builtins.splitstring(Builtins.substring(id, 7), ":")
        ls = Builtins.maplist(ls) do |s|
          Ops.less_than(Builtins.size(s), 2) ? Ops.add("0", s) : s
        end
        Builtins.y2milestone("MatchInterface ls:%1", ls)
        cmd = Builtins.sformat(
          "ifconfig | grep -i \"hwaddr.*%1\"",
          Builtins.mergestring(ls, ":")
        )
        bo = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
        ls = Builtins.splitstring(Ops.get_string(bo, "stdout", ""), "\n")
        ls = Builtins.filter(Builtins.splitstring(Ops.get(ls, 0, ""), " \t")) do |s|
          !Builtins.isempty(s)
        end
        ret = Ops.get(ls, 0, "") unless Builtins.isempty(ls)
      end
      Builtins.y2milestone("MatchInterface id:%1 ret:%2", id, ret)
      ret
    end

    def processWait(resource, stage)
      Builtins.foreach(
        Ops.get_list(Profile.current, ["general", "wait", stage], [])
      ) do |process|
        if Ops.get_string(process, "name", "") == resource
          if Builtins.haskey(process, "sleep")
            if Ops.get_boolean(process, ["sleep", "feedback"], false) == true
              Popup.ShowFeedback(
                "",
                Builtins.sformat(_("Processing resource %1"), resource)
              )
            end
            Builtins.sleep(
              Ops.multiply(1000, Ops.get_integer(process, ["sleep", "time"], 0))
            )
            Popup.ClearFeedback if Ops.get_boolean(process, ["sleep", "feedback"], false) == true
          end
          if Builtins.haskey(process, "script")
            debug = Ops.get_boolean(process, ["script", "debug"], true) ? "-x" : ""
            scriptName = Builtins.sformat("%1-%2", stage, resource)
            scriptPath = Builtins.sformat(
              "%1/%2",
              AutoinstConfig.scripts_dir,
              scriptName
            )
            SCR.Write(
              path(".target.string"),
              scriptPath,
              Ops.get_string(
                process,
                ["script", "source"],
                "echo Empty script!"
              )
            )
            executionString = Builtins.sformat(
              "/bin/sh %1 %2 2&> %3/%4.log ",
              debug,
              scriptPath,
              AutoinstConfig.logs_dir,
              scriptName
            )
            SCR.Execute(path(".target.bash"), executionString)
          end
        end
      end
      nil
    end

    def wait_systemd_finished(max_wait, ser_ignore)
      ser_ignore = deep_copy(ser_ignore)
      Builtins.y2milestone(
        "wait_systemd_finished max_wait=%1 ser_ignore=%2",
        max_wait,
        ser_ignore
      )
      st_time = Yast2::SystemTime.uptime
      cur_time = st_time
      last_busy = st_time
      cmd = "systemctl --full list-jobs"
      while Ops.less_or_equal(Ops.subtract(cur_time, st_time), max_wait) &&
          Ops.less_than(Ops.subtract(cur_time, last_busy), 5)
        out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
        Builtins.y2milestone(
          "wait_systemd_finished ret exit:%1 stderr:%2",
          Ops.get_integer(out, "exit", -1),
          Ops.get_string(out, "stderr", "")
        )
        sl = Builtins.splitstring(Ops.get_string(out, "stdout", ""), "\n")
        Builtins.y2milestone("sl=%1", sl)
        ll = Builtins.maplist(sl) do |s|
          Builtins.filter(Builtins.splitstring(s, " \t")) do |e|
            !Builtins.isempty(e)
          end
        end
        ll = Builtins.filter(ll) { |l| Ops.get_string(l, 3, "") == "running" }
        cnt = Builtins.size(Builtins.filter(ll) do |l|
          !Builtins.contains(ser_ignore, Ops.get_string(l, 1, ""))
        end)
        Builtins.y2milestone("size ll=%1 ll:%2", cnt, ll)
        last_busy = cur_time if Ops.greater_than(cnt, 0)
        Builtins.sleep(500)
        cur_time = Yast2::SystemTime.uptime
        Builtins.y2milestone(
          "wait_systemd_finished time:%1 idle:%2",
          Ops.subtract(cur_time, st_time),
          Ops.subtract(cur_time, last_busy)
        )
      end
      Builtins.y2milestone(
        "wait_systemd_finished waited time:%1",
        Ops.subtract(cur_time, st_time)
      )

      nil
    end
  end
end

Yast::InstAutoconfigureClient.new.main
