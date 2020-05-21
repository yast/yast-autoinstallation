# Copyright (c) [2020] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"

require "shellwords"

require "transfer/file_from_url"

Yast.import "AutoinstConfig"

module Y2Autoinstallation
  # Base class representing custom user script that runs during various phases of installation.
  class Script
    include Yast::Logger
    include Yast::Transfer::FileFromUrl
    include Yast::I18n

    # filename of script, used as ID
    # @return [String]
    attr_reader :filename

    # Source code of script. Either source or location should be defined.
    # @return [String] empty string means not defined
    attr_reader :source

    # URI for location from which download script. Either source or location should be defined.
    # @return [String] empty string means not defined
    attr_reader :location

    # Flag if script runs in debug mode.
    # @return [Boolean]
    attr_reader :debug

    def initialize(hash)
      @filename = hash["filename"] || ""
      @source = hash["source"] || ""
      @location = hash["location"] || ""
      @debug = !!hash["debug"]

      resolve_location
    end

    def to_hash
      {
        "filename" => filename,
        "source" => source,
        "location" => location,
        "debug" => debug
      }
    end

    def log_dir
      Yast::AutoinstConfig.logs_dir
    end

    # difference from filename is that it always return non empty string
    # @return [String]
    def script_name
      return filename unless filename.empty?

      if location.empty?
        self.class.type
      else
        url = Yast::URL.Parse(location)
        File.basename(url["path"])
      end
    end

    # location where script lives
    # @return [String]
    def script_path
      File.join(Yast::AutoinstConfig.scripts_dir, script_name)
    end

    # Downloads or writes down script file
    def create_script_file
      if !location.empty?
        url = Yast::URL.Parse(location)
        res = get_file_from_url(
          scheme: url["scheme"],
          host: url["host"],
          urlpath: url["path"],
          localfile: localfile,
          urltok: url,
          destdir: Yast::AutoinstConfig.destdir
        )
        # TODO: exception?
        log.error "script #{location} could not be retrieved" unless res
      elsif !source.empty?
        Yast::SCR.Write(Yast::Path.new(".target.string"), script_path, source)
      else
        log.error "Neither location or source specified for #{inspect}"
      end
    end

  protected

    # where to download file for get_file_from_url which do not switch itself chroot
    # Just work-around for not respecting changed chroot (see bsc#897212 and bsc#889931))
    def localfile
      script_path
    end

  private

    def resolve_location
      return if @location.empty?

      log.info "Resolving location #{@location.inspect}"
      @location.strip!
      return unless @location.start_with?("relurl://")

      path = location[9..-1] # 9 is relurl:// size

      if Yast::AutoinstConfig.scheme == "relurl"
        log.info "autoyast profile was relurl too"
        newloc = Yast::SCR.Read(Yast::Path.new(".etc.install_inf.ayrelurl"))
        tok = Yast::URL.Parse(newloc)
        @location = "#{tok["scheme"]}://#{File.join(tok["host"], File.dirname(tok["path"]), path)}"
      else
        config = Yast::AutoinstConfig
        @location = "#{config.scheme}://#{File.join(config.host, config.directory, path)}"
      end
      log.info "resolved location #{@location.inspect}"
    end
  end

  class ScriptFeedback
    # feedback settings
    # @return [:message | :warning | :error | :popup | :no]
    attr_reader :value

    def initialize(hash)
      @value = if hash["feedback"]
        case hash["feedback_type"]
        when "message" then :message
        when "warning" then :warning
        when "error" then :error
        when "", nil then :popup
        else
          raise "Unknown feedback type value #{hash["feedback_type"].inspect}"
        end
      else
        :no
      end
    end

    def to_hash
      case @value
      when :message then { "feedback" => true, "feedback_type" => "message" }
      when :warning then { "feedback" => true, "feedback_type" => "warning" }
      when :error then { "feedback" => true, "feedback_type" => "error" }
      when :popup then { "feedback" => true, "feedback_type" => "" }
      when :no then { "feedback" => false, "feedback_type" => "" }
      else
        raise "Unknown value '#{value.inspect}"
      end
    end
  end

  # Scripts that are executed by YaST ( so all expect init scripts )
  class ExecutedScript < Script
    # Sets if feedback after script finish should be shown
    # @return [ScriptFeedback]
    attr_reader :feedback

    # Interpreter to use to run script.
    # @return [String]
    attr_reader :interpreter

    # Notification message during script run
    # @return [String] empty string if no notification should be shown
    attr_reader :notification

    # Params passed to script
    # @return [Array]
    attr_reader :params

    # Reruns script even if already ran
    # @return [Boolean]
    attr_reader :rerun

    def to_hash
      res = super
      res["interpreter"] = interpreter
      res["notification"] = notification
      res["param-list"] = params
      res["rerun"] = rerun
      res.merge(feedback.to_hash)
    end

    def initialize(hash)
      super

      @feedback = ScriptFeedback.new(hash)
      @interpreter = hash["interpreter"] || "shell"
      @notification = hash["notification"] || ""
      @params = hash["param-list"] || []
      @rerun = !!hash["rerun"]
    end

    DEBUG_FLAG_MAP = {
      "shell" => "-x",
      "perl" => "-w",
      "ruby" => "-w"
    }
    INTERPRETER_MAP = {
      "shell" => "/bin/sh", # TODO: why not bash? at least user can now specify interpreter he wants
      "perl" => "/usr/bin/perl",
      "python" => "/usr/bin/python"
    }
    # Runs the script
    def execute
      return if already_run? && !rerun

      # TODO: maybe own class for interpreters?
      cmd = INTERPRETER_MAP[interpreter] || interpreter
      debug_flag = debug ? (DEBUG_FLAG_MAP[interpreter] || "") : ""
      params_s = params.join(" ") # shell escaping is up to user, see documentation

      bash_path = Yast::Path.new(".target.bash")
      Yast::SCR.Execute(bash_path,
        "#{cmd} #{debug_flag} #{script_path.shellescape} #{params_s} " \
          "&> #{log_path.shellescape}")
      Yast::SCR.Execute(bash_path, "/bin/touch #{run_file.shellescape}")
    end

    def log_path
      File.join(logs_dir, script_name + ".log")
    end

  private

    def already_run?
      Yast::SCR.Read(Yast::Path.new(".target.size"), run_file) != -1
    end

    def run_file
      script_path + "-run"
    end
  end

  # Script that runs before any other and can modify autoyast profile
  class PreScript < ExecutedScript
    def logs_dir
      File.join(Yast::AutoinstConfig.tmpDir, self.class.type, "logs")
    end

    def self.type
      "pre-scripts"
    end

    def script_path
      File.join(Yast::AutoinstConfig.tmpDir, self.class.type, script_name)
    end
  end

  # Script that runs after finish of second stage
  class PostScript < ExecutedScript
    def self.type
      "post-scripts"
    end
  end

  # Script that runs before or after changing to chroot depending on chrooted parameter
  class ChrootScript < ExecutedScript
    # Flag that defines when script should be run
    attr_reader :chrooted

    def initialize(hash)
      super

      @chrooted = !!hash["chrooted"]
    end

    def to_hash
      res = super
      res["chrooted"] = chrooted
      res
    end

    def self.type
      "chroot-scripts"
    end

    def logs_dir
      if chrooted
        super
      else
        File.join(Yast::AutoinstConfig.destdir, Yast::AutoinstConfig.logsdir)
      end
    end

  protected

    def localfile
      if chrooted
        File.join(Yast::AutoinstConfig.destdir, script_path)
      else
        super
      end
    end
  end

  # Script that runs after partitioning before rpm install
  class PostPartitioningScript < ExecutedScript
    def self.type
      "postpartitioning-scripts"
    end

    def logs_dir
      File.join(Yast::AutoinstConfig.tmpDir, self.class.type, "logs")
    end

    def script_path
      File.join(Yast::AutoinstConfig.tmpDir, self.class.type, script_name)
    end
  end

  # Runs after finish of second stage. It is executed by systemd and yast just write it down.
  class InitScript < Script
    def self.type
      "init-scripts"
    end

    def script_path
      File.join(Yast::AutoinstConfig.initscripts_dir, script_name)
    end
  end

  # List of known script 
  SCRIPT_TYPES = [PreScript, PostScript, InitScript, ChrootScript, PostPartitioningScript]
end
