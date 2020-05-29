require "yast"

require "autoinstall/script"

module Yast
  # Module responsible for autoyast scripts support.
  # See Autoyast Guide Scripts section for user documentation and some parameters explanation.
  # https://doc.opensuse.org/projects/autoyast/#createprofile-scripts
  #
  # ### Scripts WorkFlow
  # Each script type is executed from different place. Below is described each one. Execution is
  # done by calling {Yast::AutoinstScriptsClass#Write} unless mentioned differently.
  #
  # #### Pre Scripts
  # Runs before any other actions in autoyast and is executed from inst_autosetup client
  # {Yast::InstAutosetupClient}
  #
  # #### Chroot Scripts
  # Runs before installation chroot or after chroot depending on chrooted parameter.
  # The first non-chrooted variant is called from {Yast::AutoinstScripts1FinishClient}.
  # The second chrooted variant is called from {Yast::AutoinstScripts2FinishClient}.
  #
  # #### Post Scripts
  # Runs after finish of second stage. It is downloaded from {Yast::AutoinstScripts2FinishClient}.
  # Then it is executed by {Yast::InstAutoconfigureClient}.
  #
  # #### Init Scripts
  # Runs after finish of second stage. It is created at {Yast::AutoinstScripts2FinishClient} and
  # also during second stage at {Yast::InstAutoconfigureClient}. TODO: why twice?
  # Then it is executed from systemd service autoyast-initscripts.service which lives in scripts
  # directory.
  #
  # #### Post Partitioning Scripts
  # Runs after partitioning from {Yast::InstAutoimageClient} unconditionaly even when images is
  # not used.
  #
  class AutoinstScriptsClass < Module
    include Yast::Logger

    # list of all scripts
    # @return [Array<Y2Autoinstallation::Script>]
    attr_reader :scripts

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

      # Scripts list
      @scripts = []

      # default value of settings modified
      @modified = false
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

    # TODO: maybe private?
    def pre_scripts
      scripts.select { |s| s.is_a?(Y2Autoinstallation::PreScript) }
    end

    def post_scripts
      scripts.select { |s| s.is_a?(Y2Autoinstallation::PostScript) }
    end

    def chroot_scripts
      scripts.select { |s| s.is_a?(Y2Autoinstallation::ChrootScript) }
    end

    def init_scripts
      scripts.select { |s| s.is_a?(Y2Autoinstallation::InitScript) }
    end

    def postpart_scripts
      scripts.select { |s| s.is_a?(Y2Autoinstallation::PostPartitioningScript) }
    end

    # Dump the settings to a map, for autoinstallation use.
    # @return [Hash]
    def Export
      log.info "Exporting scripts #{scripts.inspect}"

      groups = scripts.group_by {|s| s.class.type }

      groups.each_with_object({}) { |(type, scs), result| result[type] = scs.map(&:to_hash) }
    end

    # Get all the configuration from a map.
    # When called by autoinst_<module name> (preparing autoinstallation data)
    # the map may be empty.
    # @param s [Hash] scripts section from an AutoYaST profile
    # @return [Boolean]
    def Import(s)
      # take only hash entries (bnc#986049)
      @scripts = []
      @scripts.concat(valid_scripts_for(s, "pre-scripts")
        .map{ |h| Y2Autoinstallation::PreScript.new(h) })
      @scripts.concat(valid_scripts_for(s, "init-scripts")
        .map{ |h| Y2Autoinstallation::InitScript.new(h) })
      @scripts.concat(valid_scripts_for(s, "post-scripts")
        .map{ |h| Y2Autoinstallation::PostScript.new(h) })
      @scripts.concat(valid_scripts_for(s, "chroot-scripts")
        .map{ |h| Y2Autoinstallation::ChrootScript.new(h) })
      @scripts.concat(valid_scripts_for(s, "postpartitioning-scripts")
        .map{ |h| Y2Autoinstallation::PostPartitioningScript.new(h) })

      # check for duplicite filenames
      known = []
      duplicites = @scripts.each_with_object([]) do |s, d|
        path = s.script_path
        if known.include?(path)
          d << s
        else
          known << path
        end
      end

      if !duplicites.empty?
        duplicites.each do |script|
          conflicting = @scripts.select { |s| s.script_path == script.script_path }
          Report.Warning(_("Following scripts will overwrite each other:") + "\n" + conflicting.map(&:inspect).join("\n"))
        end
      end

      true
    end

    # Return Summary
    # @return [String] summary
    def Summary
      summary = ""

      scripts_desc = {
        _("Preinstallation Scripts") => pre_scripts,
        _("Postinstallation Scripts") => post_scripts,
        _("Chroot Scripts") => chroot_scripts,
        _("Init Scripts") => init_scripts,
        _("Postpartitioning Scripts") => postpart_scripts
      }

      scripts_desc.each_pair do |label, scs|
        summary = Summary.AddHeader(summary, label)
        if scs.empty?
          summary = Summary.AddLine(summary, Summary.NotConfigured)
        else
          summary = Summary.OpenList(summary)
          scs.each { |s| summary = Summary.AddListItem(summary, s.filename) }
          summary = Summary.CloseList(summary)
        end
      end

      summary
    end

    # delete a script from a list
    # @param scriptName [String] script name
    # @return [void]
    def deleteScript(scriptName)
      scripts.delete_if { |s| s.filename == scriptName }

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

      deleteScript(scriptName)

      script_hash = {
        "filename" => scriptName,
        "source"=> source,
        "interpreter"=> interpreter,
        "chrooted"=> chrooted,
        "debug"=> debug,
        "feedback"=> feedback,
        "feedback_type"=> feedback_type,
        "location"=> location,
        "notification"=> notification,
      }

      klass = Y2Autoinstallation::SCRIPT_TYPES.find { |script_class| script_class.type == type }
      scripts << klass.new(script_hash)

      nil
    end

    # return type of script as formatted string
    # @param type [String] script type
    # @return [String] type as translated string
    def typeString(type)
      # TODO: move to script class
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

    # Execute pre scripts
    # @param type [String] type of script
    # @param special [Boolean] if script should be executed in chroot env.
    # @return [Boolean] true on success
    def Write(type, special)
      return true if !Mode.autoinst && !Mode.autoupgrade

      target_scripts = @scripts.select { |s| s.class.type == type }
      target_scripts.select! { |s| s.chrooted == special } if type == "chroot-scripts"

      target_scripts.each(&:create_script_file)

      return true if type == "init-scripts" # we just write init scripts and systemd execute them
      # We are in the first installation stage
      # where post-scripts have been downloaded only.
      return true if type == "post-scripts" && special

      target_scripts.each do |script|
        Popup.ShowFeedback("", script.notification) unless script.notification.empty?

        res = script.execute

        Popup.ClearFeedback unless script.notification.empty?

        feedback = if script.feedback.value == :no
          ""
        else
          SCR.Read(
            path(".target.string"),
            script.log_path
          )
        end

        if !feedback.empty?
          case script.feedback.value
          when :popup
            Popup.LongText("", RichText(Opt(:plainText), feedback), 50, 20)
          when :message
            Report.Message(feedback)
          when :warning
            Report.Warning(feedback)
          when :error
            Report.Error(feedback)
          else
            raise "Unexpected feedback_type #{script.feedback.inspect}"
          end
        # show warning if script return non-zero and no feedback is want
        elsif !res
          Report.Warning(format(
            _("User script %{script_name} failed.\nDetails:\n%{output}"),
            script_name: script.filename, output: SCR.Read(path(".target.string"), script.log_path)
          ))
        end
      end

      true
    end

    publish variable: :modified, type: "boolean"
    publish function: :SetModified, type: "void ()"
    publish function: :GetModified, type: "boolean ()"
    publish function: :Export, type: "map <string, list> ()"
    publish function: :Import, type: "boolean (map)"
    publish function: :Summary, type: "string ()"
    publish function: :deleteScript, type: "void (string)"
    publish function: :AddEditScript,
            type:     "void (string, string, string, string, boolean, boolean, " \
      "boolean, boolean, string, string, string)"
    publish function: :typeString, type: "string (string)"
    publish function: :Write, type: "boolean (string, boolean)"

  private

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
  end

  AutoinstScripts = AutoinstScriptsClass.new
  AutoinstScripts.main
end
