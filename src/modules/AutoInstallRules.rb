# encoding: utf-8

# File:	modules/AutoInstallRules.ycp
# Package:	Auto-installation
# Summary:	Process Auto-Installation Rules
# Author:	Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"

module Yast
  class AutoInstallRulesClass < Module
    include Yast::Logger

    def main
      Yast.import "UI"
      textdomain "autoinst"


      Yast.import "Arch"
      Yast.import "Stage"
      Yast.import "Installation"
      Yast.import "AutoinstConfig"
      Yast.import "XML"
      Yast.import "Storage"
      Yast.import "StorageControllers"
      Yast.import "Kernel"
      Yast.import "Mode"
      Yast.import "Profile"
      Yast.import "Label"
      Yast.import "Report"
      Yast.import "Popup"
      Yast.import "URL"
      Yast.import "IP"
      Yast.import "Product"
      Yast.import "Hostname"
      Yast.import "OSRelease"

      Yast.include self, "autoinstall/io.rb"

      reset
    end

    # Reset the module's state
    #
    # @return nil
    #
    # @see #AutoInstallRules
    def reset
      @userrules = false
      @dontmergeIsDefault = true
      @dontmergeBackup = []

      @Behaviour = :many

      #///////////////////////////////////////////
      # Pre-defined Rules
      #///////////////////////////////////////////

      # All system attributes;
      @ATTR = {}

      @installed_product = ""
      @installed_product_version = ""
      @hostname = ""
      @hostaddress = ""
      @network = ""
      @domain = ""
      @arch = ""
      @karch = ""

      # Taken from smbios
      @product = ""

      # Taken from smbios
      @product_vendor = ""

      # Taken from smbios
      @board_vendor = ""

      # Taken from smbios
      @board = ""

      @memsize = 0
      @disksize = []
      @totaldisk = 0
      @hostid = ""
      @mac = ""
      @linux = 0
      @others = 0
      @xserver = ""
      @haspcmcia = "0"

      #///////////////////////////////////////////
      #///////////////////////////////////////////
      @NonLinuxPartitions = []
      @LinuxPartitions = []
      @UserRules = {}

      # Local Variables
      @shell = ""
      @env = {}

      @tomerge = []
      @element2file = {}
      AutoInstallRules()
    end

    # Cleanup XML file from namespaces put by xslt
    def XML_cleanup(_in, out)
      ycpin = XML.XMLToYCPFile(_in)
      Builtins.y2debug("Writing clean XML file to  %1, YCP is (%2)", out, ycpin)
      XML.YCPToXMLFile(:profile, ycpin, out)
    end


    # StdErrLog()
    # Dialog for error messages
    def StdErrLog(stderr)
      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          VSpacing(0.5),
          HSpacing(50),
          HBox(
            HSpacing(0.5),
            LogView(Id(:log), Label.ErrorMsg, 10, 100),
            HSpacing(0.5)
          ),
          VSpacing(0.2),
          PushButton(Id(:ok), Opt(:default), Label.OKButton),
          VSpacing(0.5)
        )
      )

      UI.ChangeWidget(Id(:log), :Value, stderr)
      UI.UserInput
      UI.CloseDialog

      nil
    end
    # getMAC()
    # Return MAC address of active device
    # @return [String] mac address
    def getMAC
      tmpmac = ""
      if Stage.initial
        cmd = 'ip link show | grep link/ether | head -1 | sed -e "s:^.*link/ether.::" -e "s: .*::"'
        ret = SCR.Execute(path(".target.bash_output"), cmd )
	Builtins.y2milestone("mac Addr ret:%1", ret)
	tmpmac = ret.fetch("stdout","")
      end
      Builtins.y2milestone("mac Addr tmp:%1", tmpmac)
      cleanmac = Builtins.deletechars(tmpmac != nil ? tmpmac : "", ":\n")
      Builtins.y2milestone("mac Addr mac:%1", cleanmac)
      cleanmac
    end

    # Return the network part of the hostaddress
    #
    # Unless is called during initial stage (Stage.initial),
    # it always returns "192.168.1.0".
    #
    # @example
    #   AutoInstallRules.getNetwork #=> "192.168.122.0"
    #
    # @return [String] Network part of the hostaddress
    #
    # @see hostaddress
    def getNetwork
      return "192.168.1.0" unless Stage.initial # FIXME
      wicked_ret = SCR.Execute(path(".target.bash_output"),
        "/usr/sbin/wicked show --verbose all")

      # Regexp to fetch match the network address.
      regexp = / ([\h:\.]+)\/\d+ dev.+pref-src #{hostaddress}/
      if match = regexp.match(wicked_ret["stdout"])
        match[1]
      else
        log.warn "Cannot find network address through wicked: #{wicked_ret}"
        nil
      end
    end

    # Return host id (hex ip )
    # @return [String] host ID
    def getHostid
      if Stage.initial
        wicked_ret = SCR.Execute(path(".target.bash_output"), "/usr/sbin/wicked show --verbose all|grep pref-src")
        if wicked_ret["exit"] == 0
          stdout = wicked_ret["stdout"].split
          @hostaddress = stdout[stdout.index("pref-src")+1]
        else
          log.warn "Cannot evaluate IP address with wicked: #{wicked_ret["stderr"]}"
          @hostaddress = nil
        end
      else
        @hostaddress = "192.168.1.1" # FIXME
      end
      IP.ToHex(@hostaddress)
    end

    # Return host name
    # @return [String] host name
    def getHostname
      ret = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "/bin/hostname")
      )
      Builtins.y2milestone("getHostname ret:%1", ret)
      name = ""
      if Ops.get_integer(ret, "exit", -1) == 0
        name = Ops.get(
          Builtins.splitstring(Ops.get_string(ret, "stdout", ""), "\n"),
          0,
          ""
        )
      end
      if Builtins.isempty(name)
        name = Convert.to_string(SCR.Read(path(".etc.install_inf.Hostname")))
      end
      Builtins.y2milestone("getHostname name:%1", name)
      name
    end


    # Probe all system data to build  a set of rules
    # @return [void]
    def ProbeRules
      return if @ATTR.size>0
      # SMBIOS Data
      bios = Convert.to_list(SCR.Read(path(".probe.bios")))

      if Builtins.size(bios) != 1
        Builtins.y2warning("Warning: BIOS list size is %1", Builtins.size(bios))
      end

      biosinfo = Ops.get_map(bios, 0, {})
      smbios = Ops.get_list(biosinfo, "smbios", [])

      sysinfo = {}
      boardinfo = {}

      Builtins.foreach(smbios) do |inf|
        if Ops.get_string(inf, "type", "") == "sysinfo"
          sysinfo = deep_copy(inf)
        elsif Ops.get_string(inf, "type", "") == "boardinfo"
          boardinfo = deep_copy(inf)
        end
      end

      if Ops.greater_than(Builtins.size(sysinfo), 0)
        @product = Ops.get_string(sysinfo, "product", "default")
        @product_vendor = Ops.get_string(sysinfo, "manufacturer", "default")
      end

      if Ops.greater_than(Builtins.size(boardinfo), 0)
        @board = Ops.get_string(boardinfo, "product", "default")
        @board_vendor = Ops.get_string(boardinfo, "manufacturer", "default")
      end

      Ops.set(@ATTR, "product", @product)
      Ops.set(@ATTR, "product_vendor", @product_vendor)
      Ops.set(@ATTR, "board", @board)
      Ops.set(@ATTR, "board_vendor", @board_vendor)

      #
      # Architecture
      #

      @arch = Arch.architecture
      @karch = Ops.get(Kernel.GetPackages, 0, "kernel-default")

      Ops.set(@ATTR, "arch", @arch)
      Ops.set(@ATTR, "karch", @karch)

      #
      # Memory
      #

      memory = 0
      memories = Convert.to_list(SCR.Read(path(".probe.memory")))
      memory = Ops.get_integer(
        memories,
        [0, "resource", "phys_mem", 0, "range"],
        0
      )
      @memsize = Ops.divide(memory, 1024 * 1024)
      Ops.set(@ATTR, "memsize", @memsize)

      #
      # Disk sizes
      #

      StorageControllers.Initialize  # ugly hack, Storage.GetTargetMap should simply work without it
      storage = Storage.GetTargetMap
      _PhysicalTargetMap = Builtins.filter(storage) do |k, v|
        Storage.IsRealDisk(v)
      end
      @totaldisk = 0
      @disksize = Builtins.maplist(_PhysicalTargetMap) do |k, v|
        size_in_mb = Ops.divide(Ops.get_integer(v, "size_k", 0), 1024)
        @totaldisk = Ops.add(@totaldisk, size_in_mb)
        { "device" => k, "size" => size_in_mb }
      end
      Builtins.y2milestone("disksize: %1", @disksize)
      Ops.set(@ATTR, "totaldisk", @totaldisk)
      #
      # MAC
      #
      Ops.set(@ATTR, "mac", @mac)

      #
      # Network
      #
      Ops.set(@ATTR, "hostaddress", @hostaddress)

      #
      # Hostid (i.e. a8c00101);
      #
      Ops.set(@ATTR, "hostid", @hostid)

      Ops.set(@ATTR, "hostname", getHostname)
      @domain = Hostname.CurrentDomain
      Ops.set(@ATTR, "domain", @domain)
      @network = getNetwork
      Ops.set(@ATTR, "network", @network)
      @haspcmcia = Convert.to_string(
        SCR.Read(path(".etc.install_inf.HasPCMCIA"))
      )
      Ops.set(@ATTR, "haspcmcia", @haspcmcia)
      @xserver = Convert.to_string(SCR.Read(path(".etc.install_inf.XServer")))
      Ops.set(@ATTR, "xserver", @xserver)

      @NonLinuxPartitions = Storage.GetForeignPrimary
      @others = Builtins.size(@NonLinuxPartitions)

      Builtins.y2milestone("Other primaries: %1", @NonLinuxPartitions)

      @LinuxPartitions = Storage.GetOtherLinuxPartitions
      @linux = Builtins.size(@LinuxPartitions)

      Builtins.y2milestone("Other linux parts: %1", @LinuxPartitions)

      @installed_product = Yast::OSRelease.ReleaseName
      @installed_product_version = Yast::OSRelease.ReleaseVersion
      Ops.set(@ATTR, "installed_product", @installed_product)
      Ops.set(@ATTR, "installed_product_version", @installed_product_version)

      log.info "Installing #{@installed_product}, " \
        "version: #{@installed_product_version}"
      log.info "ATTR=#{@ATTR}"

      nil
    end




    # Create shell command for rule verification
    # @param [Boolean] match
    # @param [String] var
    # @param [Object] val
    # @param [String] op
    # @param [String] matchtype
    # @return [void]
    def shellseg(match, var, val, op, matchtype)
      val = deep_copy(val)
      if op == "and"
        op = " && "
      elsif op == "or"
        op = " || "
      end

      tmpshell = " ( ["
      Builtins.y2debug("Match type: %1", matchtype)
      if Ops.is_string?(val) && Convert.to_string(val) == "*"
        # match anything
        tmpshell = Ops.add(tmpshell, " \"1\" = \"1\" ")
      elsif matchtype == "exact"
        tmpshell = Ops.add(
          tmpshell,
          Builtins.sformat(" \"$%1\" = \"%2\" ", var, val)
        )
      elsif matchtype == "greater"
        tmpshell = Ops.add(
          tmpshell,
          Builtins.sformat(" \"$%1\" -gt \"%2\" ", var, val)
        )
      elsif matchtype == "lower"
        tmpshell = Ops.add(
          tmpshell,
          Builtins.sformat(" \"$%1\" -lt \"%2\" ", var, val)
        )
      elsif matchtype == "range"
        range = Builtins.splitstring(Builtins.tostring(val), "-")
        Builtins.y2debug("Range: %1", range)
        tmpshell = Ops.add(
          tmpshell,
          Builtins.sformat(
            " \"$%1\" -ge \"%2\" -a \"$%1\" -le \"%3\" ",
            var,
            Ops.get(range, 0, "0"),
            Ops.get(range, 1, "0")
          )
        )
      elsif matchtype == "regex"
        tmpshell = Ops.add(
          tmpshell,
          Builtins.sformat("[ \"$%1\" =~ %2 ]", var, val)
        )
      end

      if match
        @shell = Ops.add(@shell, Builtins.sformat(" %1 %2] )", op, tmpshell))
      else
        @shell = Ops.add(tmpshell, "] ) ")
      end

      Builtins.y2milestone("var: %1, val: %2", var, val)
      Builtins.y2milestone("shell: %1", @shell)
      nil
    end


    # Verify rules using the shell
    # @return [Fixnum]
    def verifyrules
      script = Builtins.sformat("if %1; then exit 0; else exit 1; fi", @shell)
      ret = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), script, @env)
      )

      Builtins.y2milestone("Bash return: %1 (%2) (%3)", script, ret, @env)

      Ops.get_integer(ret, "exit", -1)
    end

    def SubVars(file)
      Builtins.y2milestone("file: %1", file)
      var = ""
      first = Builtins.findfirstof(file, "@")
      last = Builtins.findlastof(file, "@")
      if first != nil && last != nil
        ffirst = Ops.add(Convert.to_integer(first), 1)
        llast = Convert.to_integer(last)
        if first != last
          var = Builtins.substring(file, ffirst, Ops.subtract(llast, ffirst))
        end
      end
      Builtins.y2milestone("var: %1", var)
      if var != ""
        val = Ops.get_string(@ATTR, var, "")
        new = Builtins.regexpsub(
          file,
          "(.*)@.*@(.*)",
          Builtins.sformat("\\1%1\\2", val)
        )
        return new if new != ""
      end
      Builtins.y2milestone("val: %1", file)
      file
    end
    # Read rules file
    # @return [void]
    def Read
      @UserRules = XML.XMLToYCPFile(AutoinstConfig.local_rules_file)

      if @UserRules == nil
        message = _("Parsing the rules file failed. XML parser reports:\n")
        Popup.Error(Ops.add(message, XML.XMLError))
      end
      Builtins.y2milestone("Rules: %1", @UserRules)

      rulelist = Ops.get_list(@UserRules, "rules", [])
      if rulelist == nil # check result of implicit type conversion
        Builtins.y2error("Key 'rules' has wrong type")
        rulelist = []
      end

      ismatch = false
      go_on = true
      AutoInstallRules.ProbeRules if !rulelist.empty?
      Builtins.foreach(rulelist) do |ruleset|
        Builtins.y2milestone("Ruleset: %1", ruleset)
	rls = ruleset.keys
	if( rls.include?("result"))
	  rls.reject! {|r| r=="result"}
	  rls.push("result")
	end
	Builtins.y2milestone("Orderes Rules: %1", rls)
        Builtins.foreach(rls) do |rule|
	  ruledef = ruleset.fetch( rule, {} )
          Builtins.y2milestone("Rule: %1", rule)
          Builtins.y2milestone("Ruledef: %1", ruledef)
          match = Ops.get_string(ruledef, "match", "undefined")
          op = Ops.get_string(ruledef, "operator", "and")
          matchtype = Ops.get_string(ruledef, "match_type", "exact")
          easy_rules = [
            "hostname",
            "hostaddress",
            "installed_product_version",
            "installed_product",
            "domain",
            "network",
            "mac",
            "karch",
            "hostid",
            "arch",
            "board",
            "board_vendor",
            "product_vendor",
            "product"
          ]
          if Builtins.contains(easy_rules, rule)
            shellseg(ismatch, rule, match, op, matchtype)
            ismatch = true
            Ops.set(@env, rule, Ops.get_string(@ATTR, rule, ""))
          elsif rule == "custom1" || rule == "custom2" || rule == "custom3" ||
              rule == "custom4" ||
              rule == "custom5"
            script = Ops.get_string(ruledef, "script", "exit -1")
            tmpdir = AutoinstConfig.tmpDir

            scriptPath = Builtins.sformat(
              "%1/%2",
              tmpdir,
              Ops.add("rule_", rule)
            )

            Builtins.y2milestone("Writing rule script into %1", scriptPath)
            SCR.Write(path(".target.string"), scriptPath, script)

            out = Convert.to_map(
              SCR.Execute(
                path(".target.bash_output"),
                Ops.add("/bin/sh ", scriptPath),
                {}
              )
            )
            script_result = Ops.get_string(out, "stdout", "")
            shellseg(ismatch, rule, match, op, matchtype)
            ismatch = true
            Ops.set(@ATTR, rule, script_result)
            Ops.set(@env, rule, script_result)
          elsif rule == "linux"
            shellseg(ismatch, rule, match, op, matchtype)
            ismatch = true
            Ops.set(@env, rule, @linux)
          elsif rule == "others"
            shellseg(ismatch, rule, match, op, matchtype)
            ismatch = true
            Ops.set(@env, rule, @others)
          elsif rule == "xserver"
            shellseg(ismatch, rule, match, op, matchtype)
            ismatch = true
            Ops.set(@env, rule, @xserver)
          elsif rule == "memsize"
            shellseg(ismatch, rule, match, op, matchtype)
            ismatch = true
            Ops.set(@env, rule, @memsize)
          elsif rule == "totaldisk"
            shellseg(ismatch, rule, match, op, matchtype)
            ismatch = true
            Ops.set(@env, rule, @totaldisk)
          elsif rule == "haspcmcia"
            shellseg(ismatch, rule, match, op, matchtype)
            ismatch = true
            Ops.set(@env, rule, @haspcmcia)
          elsif rule == "disksize"
            Builtins.y2debug("creating rule check for disksize")
            disk = Builtins.splitstring(match, " ")
            i = 0
            t = ""
            if @shell != ""
              t = Ops.add(
                @shell,
                Builtins.sformat(" %1 ( ", op == "and" ? "&&" : "||")
              )
            else
              t = Ops.add(@shell, Builtins.sformat(" ( "))
            end
            Builtins.foreach(@disksize) do |dev|
              var1 = Builtins.sformat("disksize_size%1", i)
              var2 = Builtins.sformat("disksize_device%1", i)
              if matchtype == "exact"
                t = Ops.add(
                  t,
                  Builtins.sformat(
                    " [ \"$%1\" = \"%2\" -a \"$%3\" = \"%4\" ] ",
                    var1,
                    Ops.get(disk, 1, ""),
                    var2,
                    Ops.get(disk, 0, "")
                  )
                )
              elsif matchtype == "greater"
                t = Ops.add(
                  t,
                  Builtins.sformat(
                    " [ \"$%1\" -gt \"%2\"  -a \"$%3\" = \"%4\" ] ",
                    var1,
                    Ops.get(disk, 1, ""),
                    var2,
                    Ops.get(disk, 0, "")
                  )
                )
              elsif matchtype == "lower"
                t = Ops.add(
                  t,
                  Builtins.sformat(
                    " [ \"$%1\" -lt \"%2\" -a \"$%3\" = \"%4\" ] ",
                    var1,
                    Ops.get(disk, 1, ""),
                    var2,
                    Ops.get(disk, 0, "")
                  )
                )
              end
              Ops.set(@env, var1, Ops.get_integer(dev, "size", -1))
              Ops.set(@env, var2, Ops.get_string(dev, "device", ""))
              i = Ops.add(i, 1)
              if Ops.greater_than(Builtins.size(@disksize), i)
                t = Ops.add(t, " || ")
              end
            end
            t = Ops.add(t, " ) ")
            @shell = t
            Builtins.y2debug("shell: %1", @shell)
            ismatch = true
          elsif rule == "result"
            profile_name = Ops.get_string(ruledef, "profile", "")
            profile_name = SubVars(profile_name)
            if Builtins.haskey(ruleset, "dialog")
              Ops.set(
                @element2file,
                Ops.get_integer(ruleset, ["dialog", "element"], 0),
                profile_name
              )
            end
            if verifyrules == 0
              Builtins.y2milestone("Final Profile name: %1", profile_name)
              if Ops.get_boolean(ruledef, "match_with_base", true)
                @tomerge = Builtins.add(@tomerge, profile_name)
              end
              # backdoor for merging problems.
              if Builtins.haskey(ruledef, "dont_merge")
                if @dontmergeIsDefault
                  @dontmergeBackup = deep_copy(AutoinstConfig.dontmerge)
                  AutoinstConfig.dontmerge = []
                end
                AutoinstConfig.dontmerge = Convert.convert(
                  Builtins.union(
                    AutoinstConfig.dontmerge,
                    Ops.get_list(ruledef, "dont_merge", [])
                  ),
                  :from => "list",
                  :to   => "list <string>"
                )
                @dontmergeIsDefault = false
                Builtins.y2milestone(
                  "user defined dont_merge for rules found. dontmerge is %1",
                  AutoinstConfig.dontmerge
                )
              end
              go_on = Ops.get_boolean(ruledef, "continue", false)
            else
              go_on = true
            end
            @shell = ""
            ismatch = false
          end
        end if go_on
      end

      dialogOrder = []
      Builtins.y2milestone("element2file=%1", @element2file)
      Builtins.foreach(rulelist) do |rule|
        if Builtins.haskey(rule, "dialog") &&
            !Builtins.contains(
              dialogOrder,
              Ops.get_integer(rule, ["dialog", "dialog_nr"], 0)
            )
          dialogOrder = Builtins.add(
            dialogOrder,
            Ops.get_integer(rule, ["dialog", "dialog_nr"], 0)
          )
        end
      end
      dialogOrder = Builtins.sort(dialogOrder)

      dialogIndex = 0
      while Ops.less_or_equal(
          dialogIndex,
          Ops.subtract(Builtins.size(dialogOrder), 1)
        )
        dialogNr = Ops.get(dialogOrder, dialogIndex, 0)
        dialog_term = VBox()
        element_nr = 0
        timeout = 0
        title = "Choose XML snippets to merge"
        conflictsCounter = {}
        Builtins.foreach(rulelist) do |rule|
          if Builtins.haskey(rule, "dialog")
            element_nr = Ops.get_integer(
              rule,
              ["dialog", "element"],
              element_nr
            )
            file = Ops.get(@element2file, element_nr, "")
            element_nr = Ops.add(element_nr, 1)
            if Builtins.contains(@tomerge, file)
              Builtins.foreach(Ops.get_list(rule, ["dialog", "conflicts"], [])) do |c|
                Ops.set(
                  conflictsCounter,
                  c,
                  Ops.add(Ops.get(conflictsCounter, c, 0), 1)
                )
              end
            end
          end
        end

        Builtins.foreach(rulelist) do |rule|
          if Builtins.haskey(rule, "dialog") &&
              Ops.get_integer(rule, ["dialog", "dialog_nr"], 0) == dialogNr
            element_nr = Ops.get_integer(
              rule,
              ["dialog", "element"],
              element_nr
            )
            title = Ops.get_string(rule, ["dialog", "title"], title)
            file = Ops.get(@element2file, element_nr, "")
            on = Builtins.contains(@tomerge, file) ? true : false
            button = Left(
              CheckBox(
                Id(element_nr),
                Opt(:notify),
                Ops.get_string(rule, ["dialog", "question"], file),
                on
              )
            )
            if Builtins.haskey(Ops.get(rule, "dialog", {}), "timeout")
              timeout = Ops.get_integer(rule, ["dialog", "timeout"], 0)
            end
            dialog_term = Builtins.add(dialog_term, button)
            element_nr = Ops.add(element_nr, 1)
          end
        end

        if Ops.greater_than(element_nr, 0)
          UI.OpenDialog(
            Opt(:decorated),
            VBox(
              Label(title),
              VSpacing(1),
              dialog_term,
              VSpacing(1),
              HBox(
                HStretch(),
                PushButton(Id(:back), "Back"),
                PushButton(Id(:ok), "Okay")
              )
            )
          )
          UI.ChangeWidget(Id(:back), :Enabled, false) if dialogIndex == 0
          Builtins.foreach(conflictsCounter) do |c, n|
            UI.ChangeWidget(
              Id(c),
              :Enabled,
              Ops.greater_than(n, 0) ? false : true
            )
            UI.ChangeWidget(
              Id(c),
              :Value,
              Ops.greater_than(n, 0) ? false : true
            )
          end
          while true
            ret = nil
            if timeout == 0
              ret = UI.UserInput
            else
              ret = UI.TimeoutUserInput(Ops.multiply(timeout, 1000))
            end
            timeout = 0
            element_nr = 0
            if ret == :ok || ret == :timeout || ret == :back
              dialogIndex = Ops.subtract(dialogIndex, 2) if ret == :back
              break
            else
              if Convert.to_boolean(UI.QueryWidget(Id(ret), :Value))
                @tomerge = Builtins.add(
                  @tomerge,
                  Ops.get(@element2file, Builtins.tointeger(ret), "")
                )
              else
                file = Ops.get(@element2file, Builtins.tointeger(ret), "")
                @tomerge = Builtins.filter(@tomerge) { |f| file != f }
              end
              conflicts = []
              Builtins.foreach(rulelist) do |r|
                if Ops.get_integer(r, ["dialog", "element"], -1) ==
                    Builtins.tointeger(ret)
                  conflicts = Ops.get_list(r, ["dialog", "conflicts"], [])
                  raise Break
                end
              end
              Builtins.foreach(conflicts) do |element|
                if Convert.to_boolean(UI.QueryWidget(Id(ret), :Value))
                  Ops.set(
                    conflictsCounter,
                    element,
                    Ops.add(Ops.get(conflictsCounter, element, 0), 1)
                  )
                elsif Ops.greater_than(Ops.get(conflictsCounter, element, 0), 0)
                  Ops.set(
                    conflictsCounter,
                    element,
                    Ops.subtract(Ops.get(conflictsCounter, element, 0), 1)
                  )
                end
              end
              Builtins.foreach(conflictsCounter) do |e, v|
                if Ops.greater_than(v, 0)
                  UI.ChangeWidget(Id(e), :Enabled, false)
                  UI.ChangeWidget(Id(e), :Value, false)
                else
                  UI.ChangeWidget(Id(e), :Enabled, true)
                end
              end
            end
            Builtins.y2milestone("tomerge is now = %1", @tomerge)
            Builtins.y2milestone(
              "conflictsCounter is now = %1",
              conflictsCounter
            )
          end
          UI.CloseDialog
          dialogIndex = Ops.add(dialogIndex, 1)
        end
        Builtins.y2milestone(
          "changing rules to merge to %1 because of user selection",
          @tomerge
        )
      end

      nil
    end



    # Return list of file to merge (Order matters)
    # @return [Array] list of files
    def Files
      deep_copy(@tomerge)
    end

    # Return list of file to merge (Order matters)
    # @return [Boolean]
    def GetRules
      Builtins.y2milestone("Getting Rules: %1", @tomerge)

      scheme = AutoinstConfig.scheme
      host = AutoinstConfig.host
      filepath = AutoinstConfig.filepath
      directory = AutoinstConfig.directory

      valid = []
      stop = false
      Builtins.foreach(@tomerge) do |file|
        if !stop
          dir = dirname(file)
          if dir != ""
            SCR.Execute(
              path(".target.mkdir"),
              Ops.add(Ops.add(AutoinstConfig.local_rules_location, "/"), dir)
            )
          end

          localfile = Ops.add(
            Ops.add(AutoinstConfig.local_rules_location, "/"),
            file
          )
          if !Get(
              scheme,
              host,
              Ops.add(Ops.add(directory, "/"), file),
              localfile
            )
            Builtins.y2error(
              "Error while fetching file:  %1",
              Ops.add(Ops.add(directory, "/"), file)
            )
          else
            stop = true if @Behaviour == :one
            valid = Builtins.add(valid, file)
          end
        end
      end
      @tomerge = deep_copy(valid)
      if Builtins.size(@tomerge) == 0
        Builtins.y2milestone("No files from rules found")
        return false
      else
        return true
      end
    end


    # Merge Rule results
    # @param [String] result_profile the resulting control file path
    # @return [Boolean] true on success
    def Merge(result_profile)
      tmpdir = AutoinstConfig.tmpDir
      ok = true
      skip = false
      error = false

      base_profile = Ops.add(tmpdir, "/base_profile.xml")

      Builtins.foreach(@tomerge) do |file|
        Builtins.y2milestone("Working on file: %1", file)
        current_profile = Ops.add(
          Ops.add(AutoinstConfig.local_rules_location, "/"),
          file
        )
        if !skip
          if !XML_cleanup(current_profile, Ops.add(tmpdir, "/base_profile.xml"))
            Builtins.y2error("Error reading XML file")
            message = _(
              "The XML parser reported an error while parsing the autoyast profile. The error message is:\n"
            )
            message = Ops.add(message, XML.XMLError)
            Popup.Error(message)
            error = true
          end
          skip = true
        elsif !error
          _MergeCommand = "/usr/bin/xsltproc --novalid --param replace \"'false'\" "
          dontmerge_str = ""
          i = 1
          Builtins.foreach(AutoinstConfig.dontmerge) do |dm|
            dontmerge_str = Ops.add(
              dontmerge_str,
              Builtins.sformat(" --param dontmerge%1 \"'%2'\" ", i, dm)
            )
            i = Ops.add(i, 1)
          end
          _MergeCommand = Ops.add(_MergeCommand, dontmerge_str)

          _MergeCommand = Ops.add(_MergeCommand, "--param with ")
          _MergeCommand = Ops.add(
            Ops.add(Ops.add(_MergeCommand, "\"'"), current_profile),
            "'\"  "
          )
          _MergeCommand = Ops.add(
            Ops.add(Ops.add(_MergeCommand, "--output "), tmpdir),
            "/result.xml"
          )
          _MergeCommand = Ops.add(
            _MergeCommand,
            " /usr/share/autoinstall/xslt/merge.xslt "
          )
          _MergeCommand = Ops.add(Ops.add(_MergeCommand, base_profile), " ")

          Builtins.y2milestone("Merge command: %1", _MergeCommand)
          xsltret = Convert.to_map(
            SCR.Execute(path(".target.bash_output"), _MergeCommand)
          )
          Builtins.y2milestone("Merge result: %1", xsltret)
          if Ops.get_integer(xsltret, "exit", -1) != 0 ||
              Ops.get_string(xsltret, "stderr", "") != ""
            Builtins.y2error("Merge Failed")
            StdErrLog(Ops.get_string(xsltret, "stderr", ""))
            ok = false
          end

          XML_cleanup(
            Ops.add(tmpdir, "/result.xml"),
            Ops.add(tmpdir, "/base_profile.xml")
          )
        else
          Builtins.y2error("Error while merging control files")
        end
      end

      return !error if error

      SCR.Execute(
        path(".target.bash"),
        Ops.add(
          Ops.add(Ops.add("cp ", tmpdir), "/base_profile.xml "),
          result_profile
        )
      )

      Builtins.y2milestone("Ok=%1", ok)
      @dontmergeIsDefault = true
      AutoinstConfig.dontmerge = deep_copy(@dontmergeBackup)
      ok
    end


    # Process Rules
    # @param [String] result_profile
    # @return [Boolean]
    def Process(result_profile)
      ok = true
      tmpdir = AutoinstConfig.tmpDir
      prefinal = Ops.add(
        AutoinstConfig.local_rules_location,
        "/prefinal_autoinst.xml"
      )
      return false if !Merge(prefinal)

      @tomerge = []


      # Now check if there any classes defined in theis pre final control file
      if !Profile.ReadXML(prefinal)
        Popup.Error(
          _(
            "Error while parsing the control file.\n" +
              "Check the log files for more details or fix the\n" +
              "control file and try again.\n"
          )
        )
        return false
      end
      Builtins.y2milestone("Checking classes...")
      if Builtins.haskey(Profile.current, "classes")
        Builtins.y2milestone("User defined classes available, processing....")
        classes = Ops.get_list(Profile.current, "classes", [])
        Builtins.foreach(classes) do |_class|
          # backdoor for merging problems.
          if Builtins.haskey(_class, "dont_merge")
            AutoinstConfig.dontmerge = [] if @dontmergeIsDefault
            AutoinstConfig.dontmerge = Convert.convert(
              Builtins.union(
                AutoinstConfig.dontmerge,
                Ops.get_list(_class, "dont_merge", [])
              ),
              :from => "list",
              :to   => "list <string>"
            )
            @dontmergeIsDefault = false
            Builtins.y2milestone(
              "user defined dont_merge for class found. dontmerge is %1",
              AutoinstConfig.dontmerge
            )
          end
          @tomerge = Builtins.add(
            @tomerge,
            Ops.add(
              Ops.add(
                Ops.add(
                  "classes/",
                  Ops.get_string(_class, "class_name", "none")
                ),
                "/"
              ),
              Ops.get_string(_class, "configuration", "none")
            )
          )
        end

        Builtins.y2milestone("New files to process: %1", @tomerge)
        @Behaviour = :multiple
        ret = GetRules()
        if ret
          @tomerge = Builtins.prepend(@tomerge, "prefinal_autoinst.xml")
          ok = Merge(result_profile)
        else
          Report.Error(
            _(
              "\n" +
                "User-defined classes could not be retrieved.  Make sure all classes \n" +
                "are defined correctly and available for this system via the network\n" +
                "or locally. The system cannot be installed with the original control \n" +
                "file without using classes.\n"
            )
          )

          ok = false
          SCR.Execute(
            path(".target.bash"),
            Ops.add(Ops.add(Ops.add("cp ", prefinal), " "), result_profile)
          )
        end
      else
        SCR.Execute(
          path(".target.bash"),
          Ops.add(Ops.add(Ops.add("cp ", prefinal), " "), result_profile)
        )
      end
      Builtins.y2milestone("returns=%1", ok)
      ok
    end


    # Create default rule in case no rules file is available
    # This adds a list of file starting from full hex ip representation to
    # only the first letter. Then default and finally mac address.
    # @return [void]
    def CreateDefault
      @Behaviour = :one
      if @hostid
        tmp_hex_ip = @hostid
        @tomerge << tmp_hex_ip
        while tmp_hex_ip.size > 1
          tmp_hex_ip = tmp_hex_ip[0..-2]
          @tomerge << tmp_hex_ip
        end
      end
      @tomerge << Builtins.toupper(@mac)
      @tomerge << Builtins.tolower(@mac)
      @tomerge << "default"
      Builtins.y2milestone("Created default rules=%1", @tomerge)
      nil
    end

    # Create default rule in case no rules file is available (Only one file which is given by the user)
    # @param [String] filename file name
    # @return [void]
    def CreateFile(filename)
      @tomerge = Builtins.add(@tomerge, filename)
      Builtins.y2milestone("Created default rules: %1", @tomerge)
      nil
    end
    # Constructor
    #
    def AutoInstallRules
      @mac = getMAC
      @hostid = getHostid
      Builtins.y2milestone("init mac:%1 hostid:%2", @mac, @hostid)
      nil
    end


    publish :variable => :userrules, :type => "boolean"
    publish :variable => :dontmergeIsDefault, :type => "boolean"
    publish :variable => :dontmergeBackup, :type => "list <string>"
    publish :variable => :Behaviour, :type => "symbol"
    publish :variable => :installed_product, :type => "string"
    publish :variable => :installed_product_version, :type => "string"
    publish :variable => :hostname, :type => "string"
    publish :variable => :hostaddress, :type => "string"
    publish :variable => :network, :type => "string"
    publish :variable => :domain, :type => "string"
    publish :variable => :arch, :type => "string"
    publish :variable => :karch, :type => "string"
    publish :variable => :product, :type => "string"
    publish :variable => :product_vendor, :type => "string"
    publish :variable => :board_vendor, :type => "string"
    publish :variable => :board, :type => "string"
    publish :variable => :memsize, :type => "integer"
    publish :variable => :disksize, :type => "list <map <string, any>>"
    publish :variable => :totaldisk, :type => "integer"
    publish :variable => :hostid, :type => "string"
    publish :variable => :mac, :type => "string"
    publish :variable => :linux, :type => "integer"
    publish :variable => :others, :type => "integer"
    publish :variable => :xserver, :type => "string"
    publish :variable => :haspcmcia, :type => "string"
    publish :variable => :NonLinuxPartitions, :type => "list"
    publish :variable => :LinuxPartitions, :type => "list"
    publish :variable => :UserRules, :type => "map <string, any>"
    publish :variable => :tomerge, :type => "list <string>"
    publish :function => :XML_cleanup, :type => "boolean (string, string)"
    publish :function => :StdErrLog, :type => "void (string)"
    publish :function => :getMAC, :type => "string ()"
    publish :function => :getHostid, :type => "string ()"
    publish :function => :getHostname, :type => "string ()"
    publish :function => :ProbeRules, :type => "void ()"
    publish :function => :Read, :type => "void ()"
    publish :function => :Files, :type => "list <string> ()"
    publish :function => :GetRules, :type => "boolean ()"
    publish :function => :Merge, :type => "boolean (string)"
    publish :function => :Process, :type => "boolean (string)"
    publish :function => :CreateDefault, :type => "void ()"
    publish :function => :CreateFile, :type => "void (string)"
    publish :function => :AutoInstallRules, :type => "void ()"
  end

  AutoInstallRules = AutoInstallRulesClass.new
  AutoInstallRules.main
end
