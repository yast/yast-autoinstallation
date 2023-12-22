# File:  clients/inst_autoconfigure.ycp
# Package:  Auto-installation
# Author:      Anas Nashif <nashif@suse.de>
# Summary:  This module finishes auto-installation and configures
#    the system as described in the profile file.
#
# $Id$

require "yast2/system_time"

require "autoinstall/entries/description_sorter"
require "autoinstall/entries/registry"
require "autoinstall/importer"
require "autoinstall/package_searcher"

module Yast
  class InstAutoconfigureClient < Client
    include Yast::Logger

    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.import "AutoinstConfig"
      Yast.import "AutoinstGeneral"
      Yast.import "AutoinstScripts"
      Yast.import "Call"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Profile"
      Yast.import "Report"
      Yast.import "Wizard"

      @current_step = 0 # Required by logStep()

      @resource = ""
      @module_auto = ""

      # Help text for last dialog of base installation
      @help_text = _(
        "<p>\n" \
        "Please wait while the system is being configured.\n" \
        "</p>"
      )

      log.info "Profile general,mode:#{AutoinstGeneral.mode.inspect}"
      need_systemd_isolate = AutoinstGeneral.mode.fetch("activate_systemd_default_target", true)
      final_restart_services = AutoinstGeneral.mode.fetch("final_restart_services", true)
      registry = Y2Autoinstallation::Entries::Registry.instance
      # additional for scripting and finished message
      @max_steps = registry.writable_descriptions.size + 3
      @max_steps = Ops.add(@max_steps, 1) if need_systemd_isolate
      @max_steps += 1 if final_restart_services
      Builtins.y2milestone(
        "max steps: %1 need_isolate:%2",
        @max_steps,
        need_systemd_isolate
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

      # Report only those that are 'not unsupported', these were already reported
      # Unsupported sections have already been reported in the first stage
      importer = Y2Autoinstallation::Importer.new(Profile.current)
      unsupported_sections = importer.obsolete_sections
      unknown_sections = importer.unhandled_sections - unsupported_sections
      if unknown_sections.any?
        log.error "Could not process these unknown profile sections: #{unknown_sections}"
        needed_packages = Y2Autoinstallation::PackagerSearcher.new(
          unknown_sections
        ).evaluate_via_rpm
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

      descriptions = registry.writable_descriptions
      descriptions = Y2Autoinstallation::Entries::DescriptionSorter.new(descriptions).sort

      log.info "Order: #{descriptions.inspect}"

      descriptions.each do |description|
        log.info "Processing #{description.inspect}"

        processWait(description.module_name, "pre-modules")

        result = importer.import_entry(description)
        log.info "Imported #{result.inspect}"

        Call.Function(description.client_name, ["Write"]) unless result.sections.empty?

        processWait(description.module_name, "post-modules")

        @current_step = Ops.add(@current_step, 1)
        UI.ChangeWidget(Id(:progress), :Value, @current_step)

      end
      # Initialize scripts stack
      AutoinstScripts.Import(Profile.current.fetch_as_hash("scripts"))

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
          # AddEditScript(scriptName, source, interpreter, type, chrooted, debug, feedback,
          #  feedback_type, location, notification)
          # make sure to avoid conflicts with "zzz_reboot" script here
          # https://github.com/yast/yast-autoinstallation/blob/104c18f1a56d02ab50055cdf09653db964b97888/src/modules/Profile.rb#L157
          AutoinstScripts.AddEditScript("zzzz_reboot", "shutdown -r now", "shell", "init-scripts",
            false, false, false, "", "", "") # wonderful API without defaults
        end
      end

      logStep(_("Executing Post-Scripts"))
      AutoinstScripts.Write("post-scripts", false)

      logStep(_("Writing Init-Scripts"))
      AutoinstScripts.Write("init-scripts", false)

      max_wait = AutoinstGeneral.mode.fetch("max_systemd_wait", 30)

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
        @sl = Ops.get_string(@out, "stdout", "").split("\n").collect { |c| c.split.first }
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
        wait_systemd_finished(max_wait, @ser_ignore)
      else
        Builtins.y2milestone("Do not restart all services (defined in autoyast.xml)")
      end
      if need_systemd_isolate
        logStep(_("Activating systemd default target"))
        @cmd = "systemctl --no-block --ignore-dependencies isolate default.target"
        Builtins.y2milestone("before calling \"%1\"", @cmd)
        @out = Convert.to_map(SCR.Execute(path(".target.bash_output"), @cmd))
        Builtins.y2milestone("after  calling \"%1\"", @cmd)
        Builtins.y2milestone("ret=%1", @out)
        wait_systemd_finished(max_wait, @ser_ignore)
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
      AutoinstGeneral.processes_to_wait(stage).each do |process|
        next if Ops.get_string(process, "name", "") != resource

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
        next unless Builtins.haskey(process, "script")

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
