# File:  modules/Profile.ycp
# Module:  Auto-Installation
# Summary:  Profile handling
# Authors:  Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"
require "yast2/popup"

module Yast
  class ProfileClass < Module
    include Yast::Logger

    # All these sections are handled by AutoYaST (or Installer) itself,
    # it doesn't use any external AutoYaST client for them
    GENERIC_PROFILE_SECTIONS = [
      # AutoYaST has its own partitioning
      "partitioning",
      "partitioning_advanced",
      # AutoYaST has its Preboot Execution Environment configuration
      "pxe",
      # Flags for setting the solver while the upgrade process with AutoYaST
      "upgrade",
      # Flags for controlling the update backups (see Installation module)
      "backup",
      # init section used by Kickstart and to pass additional arguments
      # to Linuxrc (bsc#962526)
      "init"
    ].freeze

    # Dropped YaST modules that used to provide AutoYaST functionality
    # bsc#925381
    OBSOLETE_PROFILE_SECTIONS = [
      # FATE#316185: Drop YaST AutoFS module
      "autofs",
      # FATE#308682: Drop yast2-backup and yast2-restore modules
      "restore",
      "sshd",
      # Defined in SUSE Manager but will not be used anymore. (bnc#955878)
      "cobbler",
      # FATE#323373 drop xinetd from distro and yast2-inetd
      "inetd",
      # FATE#319119 drop yast2-ca-manament
      "ca_mgm"
    ].freeze

    # Sections that are handled by AutoYaST clients included in autoyast2 package.
    AUTOYAST_CLIENTS = [
      "files",
      "general",
      # FIXME: Partitioning should probably not be here. There is no
      # partitioning_auto client. Moreover, it looks pointless to enforce the
      # installation of autoyast2 only because the <partitioning> section
      # is in the profile. It will happen on 1st stage anyways.
      "partitioning",
      "report",
      "scripts",
      "software"
    ].freeze

    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.import "Stage"
      Yast.import "Mode"
      Yast.import "AutoinstConfig"
      Yast.import "XML"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "ProductControl"
      Yast.import "Directory"
      Yast.import "FileUtils"
      Yast.import "PackageSystem"
      Yast.import "AutoinstFunctions"

      Yast.include self, "autoinstall/xml.rb"

      # The Complete current Profile
      @current = {}

      # defined in Y2ModuleConfig
      @ModuleMap = {}

      @changed = false

      @prepare = true
      Profile()
    end

    # Constructor
    # @return [void]
    def Profile
      #
      # setup profile XML parameters for writing
      #
      profileSetup
      SCR.Execute(path(".target.mkdir"), AutoinstConfig.profile_dir) if Stage.initial
      nil
    end

    # compatibility to new storage lib in 10.0
    def storageLibCompat
      newPart = []
      Builtins.foreach(Ops.get_list(@current, "partitioning", [])) do |d|
        if Builtins.haskey(d, "is_lvm_vg") &&
            Ops.get_boolean(d, "is_lvm_vg", false) == true
          d = Builtins.remove(d, "is_lvm_vg")
          Ops.set(d, "type", :CT_LVM)
        elsif Builtins.haskey(d, "device") &&
            Ops.get_string(d, "device", "") == "/dev/md"
          Ops.set(d, "type", :CT_MD)
        elsif !Builtins.haskey(d, "type")
          Ops.set(d, "type", :CT_DISK)
        end
        # actually, this is not a compatibility hook for the new
        # storage lib. It's a hook to be compatibel with the autoyast
        # documentation for reusing partitions
        #
        Ops.set(
          d,
          "partitions",
          Builtins.maplist(Ops.get_list(d, "partitions", [])) do |p|
            if Builtins.haskey(p, "create") &&
                Ops.get_boolean(p, "create", true) == false &&
                Builtins.haskey(p, "partition_nr")
              Ops.set(p, "usepart", Ops.get_integer(p, "partition_nr", 0)) # useless default
            end
            if Builtins.haskey(p, "partition_id")
              # that's a bit strange. There is a naming mixup between
              # autoyast and the storage part of yast. Actually filesystem_id
              # does not make sense at all but in autoyast it is the
              # partition id (maybe that's because yast calls
              # the partition id "fsid" internally).
              # partition_id in the profile does not work at all, so we copy
              # that value to filesystem_id
              Ops.set(p, "filesystem_id", Ops.get_integer(p, "partition_id", 0))
            end
            deep_copy(p)
          end
        )
        newPart = Builtins.add(newPart, d)
      end
      Builtins.y2milestone("partitioning is now %1", newPart)
      Ops.set(@current, "partitioning", newPart)

      nil
    end

    def softwareCompat
      Ops.set(@current, "software", Ops.get_map(@current, "software", {}))

      # We need to check if second stage was disabled in the profile itself
      # because AutoinstConfig is not initialized at this point
      # and InstFuntions#second_stage_required? depends on that module
      # to check if 2nd stage is required (chicken-and-egg problem).
      mode = @current.fetch("general", {}).fetch("mode", {})
      second_stage_enabled = mode.key?("second_stage") ? mode["second_stage"] : true
      add_autoyast_packages if AutoinstFunctions.second_stage_required? && second_stage_enabled

      # workaround for missing "REQUIRES" in content file to stay backward compatible
      # FIXME: needs a more sophisticated or compatibility breaking solution after SLES11
      if Builtins.size(Ops.get_list(@current, ["software", "patterns"], [])) == 0
        Ops.set(@current, ["software", "patterns"], ["base"])
      end

      nil
    end

    # compatibility to new language,keyboard and timezone client in 10.1
    def generalCompat
      if Builtins.haskey(@current, "general")
        if Builtins.haskey(Ops.get_map(@current, "general", {}), "keyboard")
          Ops.set(
            @current,
            "keyboard",
            Ops.get_map(@current, ["general", "keyboard"], {})
          )
          Ops.set(
            @current,
            "general",
            Builtins.remove(Ops.get_map(@current, "general", {}), "keyboard")
          )
        end
        if Builtins.haskey(Ops.get_map(@current, "general", {}), "language")
          Ops.set(
            @current,
            "language",
            "language" => Ops.get_string(
              @current,
              ["general", "language"],
              ""
            )
          )
          Ops.set(
            @current,
            "general",
            Builtins.remove(Ops.get_map(@current, "general", {}), "language")
          )
        end
        if Builtins.haskey(Ops.get_map(@current, "general", {}), "clock")
          Ops.set(
            @current,
            "timezone",
            Ops.get_map(@current, ["general", "clock"], {})
          )
          Ops.set(
            @current,
            "general",
            Builtins.remove(Ops.get_map(@current, "general", {}), "clock")
          )
        end
        if Ops.get_boolean(@current, ["general", "mode", "final_halt"], false)
          script = {
            "filename" => "zzz_halt",
            "source"   => "shutdown -h now"
          }
          Ops.set(@current, "scripts", {}) if !Builtins.haskey(@current, "scripts")
          if !Builtins.haskey(
            Ops.get_map(@current, "scripts", {}),
            "init-scripts"
          )
            Ops.set(@current, ["scripts", "init-scripts"], [])
          end
          Ops.set(
            @current,
            ["scripts", "init-scripts"],
            Builtins.add(
              Ops.get_list(@current, ["scripts", "init-scripts"], []),
              script
            )
          )
        end
        if Ops.get_boolean(@current, ["general", "mode", "final_reboot"], false)
          script = {
            "filename" => "zzz_reboot",
            "source"   => "shutdown -r now"
          }
          Ops.set(@current, "scripts", {}) if !Builtins.haskey(@current, "scripts")
          if !Builtins.haskey(
            Ops.get_map(@current, "scripts", {}),
            "init-scripts"
          )
            Ops.set(@current, ["scripts", "init-scripts"], [])
          end
          Ops.set(
            @current,
            ["scripts", "init-scripts"],
            Builtins.add(
              Ops.get_list(@current, ["scripts", "init-scripts"], []),
              script
            )
          )
        end
        if Builtins.haskey(
          Ops.get_map(@current, "software", {}),
          "additional_locales"
        )
          Ops.set(@current, "language", {}) if !Builtins.haskey(@current, "language")
          Ops.set(
            @current,
            ["language", "languages"],
            Builtins.mergestring(
              Ops.get_list(@current, ["software", "additional_locales"], []),
              ","
            )
          )
          Ops.set(
            @current,
            "software",
            Builtins.remove(
              Ops.get_map(@current, "software", {}),
              "additional_locales"
            )
          )
        end
      end

      nil
    end

    # Read Profile properties and Version
    # @param properties [Hash] Profile Properties
    # @return [void]
    def check_version(properties)
      version = properties["version"]
      if version != "3.0"
        Builtins.y2milestone("Wrong profile version '#{version}'")
      else
        Builtins.y2milestone("AutoYaST Profile Version  %1 Detected.", version)
      end
    end

    # Import Profile
    # @param [Hash{String => Object}] profile
    # @return [void]
    def Import(profile)
      profile = deep_copy(profile)
      Builtins.y2milestone("importing profile")
      @current = deep_copy(profile)

      check_version(Ops.get_map(@current, "properties", {}))

      # old style
      if Builtins.haskey(profile, "configure") ||
          Builtins.haskey(profile, "install")
        __configure = Ops.get_map(profile, "configure", {})
        __install = Ops.get_map(profile, "install", {})
        @current = Builtins.remove(@current, "configure") if Builtins.haskey(profile, "configure")
        @current = Builtins.remove(@current, "install") if Builtins.haskey(profile, "install")
        tmp = Convert.convert(
          Builtins.union(__configure, __install),
          from: "map",
          to:   "map <string, any>"
        )
        @current = Convert.convert(
          Builtins.union(tmp, @current),
          from: "map",
          to:   "map <string, any>"
        )
      end

      # raise the network immediately after configuring it
      if Builtins.haskey(@current, "networking") &&
          !Builtins.haskey(
            Ops.get_map(@current, "networking", {}),
            "start_immediately"
          )
        Ops.set(@current, ["networking", "start_immediately"], true)
        Builtins.y2milestone("start_immediately set to true")
      end
      merge_resource_aliases!
      storageLibCompat # compatibility to new storage library (SL 10.0)
      generalCompat # compatibility to new language,keyboard and timezone (SL10.1)
      softwareCompat

      Builtins.y2debug("Current Profile=%1", @current)
      nil
    end

    # Prepare Profile for saving and remove empty data structs
    # @return [void]
    def Prepare
      return if !@prepare

      Popup.ShowFeedback(
        _("Collecting configuration data..."),
        _("This may take a while")
      )

      e = []

      Builtins.foreach(@ModuleMap) do |p, d|
        #
        # Set resource name, if not using default value
        #
        resource = Ops.get_string(d, "X-SuSE-YaST-AutoInstResource", "")
        resource = p if resource == ""
        tomerge = Ops.get_string(d, "X-SuSE-YaST-AutoInstMerge", "")
        module_auto = Ops.get_string(d, "X-SuSE-YaST-AutoInstClient", "none")
        if Convert.to_boolean(WFM.CallFunction(module_auto, ["GetModified"]))
          resource_data = WFM.CallFunction(module_auto, ["Export"])

          s = 0
          if tomerge == ""
            s = if Ops.get_string(d, "X-SuSE-YaST-AutoInstDataType", "map") == "map"
              Builtins.size(Convert.to_map(resource_data))
            else
              Builtins.size(Convert.to_list(resource_data))
            end
          end

          if s != 0 || tomerge != ""
            if Ops.greater_than(Builtins.size(tomerge), 0)
              i = 0
              tomergetypes = Ops.get_string(
                d,
                "X-SuSE-YaST-AutoInstMergeTypes",
                ""
              )
              _MergeTypes = Builtins.splitstring(tomergetypes, ",")

              Builtins.foreach(Builtins.splitstring(tomerge, ",")) do |res|
                rd = Convert.convert(
                  resource_data,
                  from: "any",
                  to:   "map <string, any>"
                )
                if Ops.get_string(_MergeTypes, i, "map") == "map"
                  Ops.set(@current, res, Ops.get_map(rd, res, {}))
                else
                  Ops.set(@current, res, Ops.get_list(rd, res, []))
                end
                i = Ops.add(i, 1)
              end
            else
              Ops.set(@current, resource, resource_data)
            end
          elsif s == 0
            e = Builtins.add(e, resource)
          end
        end
      end

      Builtins.foreach(@current) do |k, v|
        Ops.set(@current, k, v) if !Builtins.haskey(@current, k) && !Builtins.contains(e, k)
      end

      Popup.ClearFeedback
      @prepare = false
      nil
    end

    # Reset profile to initial status
    # @return [void]
    def Reset
      Builtins.y2milestone("Resetting profile contents")
      @current = {}
      nil
    end

    # Save YCP data into XML
    # @param  file [String] path to file
    # @return [Boolean] true on success
    def Save(file)
      Prepare()
      ret = false
      Builtins.y2debug("Saving data (%1) to XML file %2", @current, file)
      if AutoinstConfig.ProfileEncrypted
        xml = XML.YCPToXMLString(:profile, @current)
        if Ops.greater_than(Builtins.size(xml), 0)
          if AutoinstConfig.ProfilePassword == ""
            p = ""
            q = ""
            begin
              UI.OpenDialog(
                VBox(
                  Label(
                    _("Encrypted AutoYaST profile. Enter the password twice.")
                  ),
                  Password(Id(:password), ""),
                  Password(Id(:password2), ""),
                  PushButton(Id(:ok), Label.OKButton)
                )
              )
              button = nil
              begin
                button = UI.UserInput
                p = Convert.to_string(UI.QueryWidget(Id(:password), :Value))
                q = Convert.to_string(UI.QueryWidget(Id(:password2), :Value))
              end until button == :ok
              UI.CloseDialog
            end while p != q
            AutoinstConfig.ProfilePassword = AutoinstConfig.ShellEscape(p)
          end
          dir = Convert.to_string(SCR.Read(path(".target.tmpdir")))
          command = Builtins.sformat(
            "gpg2 -c --armor --batch --passphrase \"%1\" --output %2/encrypted_autoyast.xml",
            AutoinstConfig.ProfilePassword,
            dir
          )
          SCR.Execute(path(".target.bash_input"), command, xml)
          if Ops.greater_than(
            SCR.Read(
              path(".target.size"),
              Ops.add(dir, "/encrypted_autoyast.xml")
            ),
            0
          )
            command = Builtins.sformat(
              "mv %1/encrypted_autoyast.xml %2",
              dir,
              file
            )
            SCR.Execute(path(".target.bash"), command, {})
            ret = true
          end
        end
      else
        ret = XML.YCPToXMLFile(:profile, @current, file)
      end
      ret
    end

    # Save sections of current profile to separate files
    #
    # @param [String] dir - directory to store section xml files in
    # @return    - list of filenames
    def SaveSingleSections(dir)
      Prepare()
      Builtins.y2milestone("Saving data (%1) to XML single files", @current)
      sectionFiles = {}
      Builtins.foreach(@current) do |sectionName, section|
        sectionFileName = Ops.add(
          Ops.add(Ops.add(dir, "/"), sectionName),
          ".xml"
        )
        tmpProfile = { sectionName => section }
        if XML.YCPToXMLFile(:profile, tmpProfile, sectionFileName)
          Builtins.y2milestone(
            "Wrote section %1 to file %2",
            sectionName,
            sectionFileName
          )
          sectionFiles = Builtins.add(
            sectionFiles,
            sectionName,
            sectionFileName
          )
        else
          Builtins.y2error(
            Builtins.sformat(
              _("Could not write section %1 to file %2."),
              sectionName,
              sectionFileName
            )
          )
        end
      end
      deep_copy(sectionFiles)
    end

    # Save the current data into a file to be read after a reboot.
    # @param parsedControlFile [Hash] Data from control file
    # @return  true on success
    # @see #Restore()
    def SaveProfileStructure(parsedControlFile)
      Builtins.y2milestone("Saving control file in YCP format")
      SCR.Write(path(".target.ycp"), parsedControlFile, @current)
    end

    # Read YCP data as the control file
    # @param parsedControlFile [Hash] ycp file
    # @return [Boolean]
    def ReadProfileStructure(parsedControlFile)
      @current = Convert.convert(
        SCR.Read(path(".target.ycp"), [parsedControlFile, {}]),
        from: "any",
        to:   "map <string, any>"
      )
      if @current == {}
        return false
      else
        Import(@current)
      end

      true
    end

    # General compatibility issues
    # @param __current [Hash] current profile
    # @return [Hash] converted profile
    def Compat(__current)
      __current = deep_copy(__current)
      # scripts
      if Builtins.haskey(__current, "pre-scripts") ||
          Builtins.haskey(__current, "post-scripts") ||
          Builtins.haskey(__current, "chroot-scripts")
        pre = Ops.get_list(__current, "pre-scripts", [])
        post = Ops.get_list(__current, "post-scripts", [])
        chroot = Ops.get_list(__current, "chroot-scripts", [])
        scripts = {
          "pre-scripts"    => pre,
          "post-scripts"   => post,
          "chroot-scripts" => chroot
        }
        __current = Builtins.remove(__current, "pre-scripts")
        __current = Builtins.remove(__current, "post-scripts")
        __current = Builtins.remove(__current, "chroot-scripts")

        Ops.set(__current, "scripts", scripts)
      end

      # general
      old = false

      general_options = Ops.get_map(__current, "general", {})
      security = Ops.get_map(__current, "security", {})
      report = Ops.get_map(__current, "report", {})

      Builtins.foreach(general_options) do |k, v|
        if k == "keyboard" && Ops.is_string?(v)
          old = true
        elsif k == "encryption_method"
          old = true
        elsif k == "timezone" && Ops.is_string?(v)
          old = true
        end
      end

      new_general = {}

      if old
        Builtins.y2milestone("Old format, converting.....")
        Ops.set(
          new_general,
          "language",
          Ops.get_string(general_options, "language", "")
        )
        keyboard = {}
        Ops.set(
          keyboard,
          "keymap",
          Ops.get_string(general_options, "keyboard", "")
        )
        Ops.set(new_general, "keyboard", keyboard)

        clock = {}
        Ops.set(
          clock,
          "timezone",
          Ops.get_string(general_options, "timezone", "")
        )
        if Ops.get_string(general_options, "hwclock", "") == "localtime"
          Ops.set(clock, "hwclock", "localtime")
        elsif Ops.get_string(general_options, "hwclock", "") == "GMT"
          Ops.set(clock, "hwclock", "GMT")
        end
        Ops.set(new_general, "clock", clock)

        mode = {}
        if Builtins.haskey(general_options, "reboot")
          Ops.set(
            mode,
            "reboot",
            Ops.get_boolean(general_options, "reboot", false)
          )
        end
        if Builtins.haskey(report, "confirm")
          Ops.set(mode, "confirm", Ops.get_boolean(report, "confirm", false))
          report = Builtins.remove(report, "confirm")
        end
        Ops.set(new_general, "mode", mode)

        if Builtins.haskey(general_options, "encryption_method")
          Ops.set(
            security,
            "encryption",
            Ops.get_string(general_options, "encryption_method", "")
          )
        end

        net = Ops.get_map(__current, "networking", {})
        ifaces = Ops.get_list(net, "interfaces", [])

        newifaces = Builtins.maplist(ifaces) do |iface|
          newiface = Builtins.mapmap(iface) do |k, v|
            { Builtins.tolower(k) => v }
          end
          deep_copy(newiface)
        end

        Ops.set(net, "interfaces", newifaces)

        Ops.set(__current, "general", new_general)
        Ops.set(__current, "report", report)
        Ops.set(__current, "security", security)
        Ops.set(__current, "networking", net)
      end

      deep_copy(__current)
    end

    # Read XML into  YCP data
    # @param file [String] path to file
    # @return [Boolean]
    def ReadXML(file)
      begin
        tmp = Convert.to_string(SCR.Read(path(".target.string"), file))
        l = Builtins.splitstring(tmp, "\n")
        if !tmp.nil? && Ops.get(l, 0, "") == "-----BEGIN PGP MESSAGE-----"
          out = {}
          while Ops.get_string(out, "stdout", "") == ""
            UI.OpenDialog(
              VBox(
                Label(
                  _("Encrypted AutoYaST profile. Enter the correct password.")
                ),
                Password(Id(:password), ""),
                PushButton(Id(:ok), Label.OKButton)
              )
            )
            p = ""
            button = nil
            begin
              button = UI.UserInput
              p = Convert.to_string(UI.QueryWidget(Id(:password), :Value))
            end until button == :ok
            UI.CloseDialog
            command = Builtins.sformat(
              "gpg2 -d --batch --passphrase \"%1\" %2",
              p,
              file
            )
            out = Convert.convert(
              SCR.Execute(path(".target.bash_output"), command, {}),
              from: "any",
              to:   "map <string, any>"
            )
          end
          @current = XML.XMLToYCPString(Ops.get_string(out, "stdout", ""))
          AutoinstConfig.ProfileEncrypted = true

          # FIXME: rethink and check for sanity of that!
          # save decrypted profile for modifying pre-scripts
          if Stage.initial
            SCR.Write(
              path(".target.string"),
              file,
              Ops.get_string(out, "stdout", "")
            )
          end
        else
          Builtins.y2debug("Reading %1", file)
          @current = XML.XMLToYCPFile(file)
        end
      rescue Yast::XMLDeserializationError => e
        # autoyast has read the autoyast configuration file but something went wrong
        message = _(
          "The XML parser reported an error while parsing the autoyast profile. " \
            "The error message is:\n"
        )
        message += e.message
        log.info "xml parsing error #{e.inspect}"
        Yast2::Popup.show(message, headline: :error)
        return false
      end

      Import(@current)
      true
    end

    def setMValue(l, v, m)
      l = deep_copy(l)
      v = deep_copy(v)
      m = deep_copy(m)
      i = Ops.get_string(l, 0, "")
      tmp = Builtins.remove(l, 0)
      if Ops.greater_than(Builtins.size(tmp), 0)
        if Ops.is_string?(Ops.get(tmp, 0))
          Ops.set(m, i, setMValue(tmp, v, Ops.get_map(m, i, {})))
        else
          Ops.set(m, i, setLValue(tmp, v, Ops.get_list(m, i, [])))
        end
      else
        Builtins.y2debug("setting %1 to %2", i, v)
        Ops.set(m, i, v)
      end
      deep_copy(m)
    end

    def setLValue(l, v, m)
      l = deep_copy(l)
      v = deep_copy(v)
      m = deep_copy(m)
      i = Ops.get_integer(l, 0, 0)
      tmp = Builtins.remove(l, 0)
      if Ops.greater_than(Builtins.size(tmp), 0)
        if Ops.is_string?(Ops.get(tmp, 0))
          Ops.set(m, i, setMValue(tmp, v, Ops.get_map(m, i, {})))
        else
          Ops.set(m, i, setLValue(tmp, v, Ops.get_list(m, i, [])))
        end
      else
        Builtins.y2debug("setting %1 to %2", i, v)
        Ops.set(m, i, v)
      end
      deep_copy(m)
    end

    #  this function is a replacement for this code:
    #      list<any> l = [ "key1",0,"key3" ];
    #      m[ l ] = v;
    #  @return [Hash]
    def setElementByList(l, v, m)
      l = deep_copy(l)
      v = deep_copy(v)
      m = deep_copy(m)
      m = setMValue(l, v, m)
      deep_copy(m)
    end

    def checkProfile
      file = Ops.add(Ops.add(AutoinstConfig.tmpDir, "/"), "valid.xml")
      Save(file)
      summary = "Some schema check failed!\n" \
        "Please attach your logfile to bug id 211014\n" \
        "\n"
      valid = true

      validators = [
        [
          _("Checking XML with RNG validation..."),
          Ops.add(
            Ops.add("/usr/bin/xmllint --noout --relaxng ", Directory.schemadir),
            "/autoyast/rng/profile.rng"
          ),
          ""
        ]
      ]
      if !Stage.cont && PackageSystem.Installed("jing")
        validators = Builtins.add(
          validators,
          [
            _("Checking XML with RNC validation..."),
            Ops.add(
              Ops.add("/usr/bin/jing >&2 -c ", Directory.schemadir),
              "/autoyast/rnc/profile.rnc"
            ),
            "jing_sucks"
          ]
        )
      end

      Builtins.foreach(validators) do |i|
        header = Ops.get_string(i, 0, "")
        cmd = Ops.add(Ops.add(Ops.get_string(i, 1, ""), " "), file)
        summary = Ops.add(Ops.add(summary, header), "\n")
        o = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
        Builtins.y2debug("validation output: %1", o)
        summary = Ops.add(Ops.add(summary, cmd), "\n")
        summary = Ops.add(
          Ops.add(summary, Ops.get_string(o, "stderr", "")),
          "\n"
        )
        summary = Ops.add(summary, "\n")
        if Ops.get_integer(o, "exit", 1) != 0 ||
            Ops.get_string(i, 2, "") == "jing_sucks" &&
                Ops.greater_than(
                  Builtins.size(Ops.get_string(o, "stderr", "")),
                  0
                )
          valid = false
        end
      end
      if !valid
        Popup.Error(summary)
        Builtins.y2milestone(
          "Profile check failed please attach the log to bug id 211014: %1",
          summary
        )
      end

      nil
    end

    # Removes the given sections from the profile
    #
    # @param sections [String,Array<String>] Section names.
    # @return [Hash] The profile without the removed sections.
    def remove_sections(sections)
      keys_to_delete = Array(sections)
      @current.delete_if { |k, _v| keys_to_delete.include?(k) }
    end

    # Returns a list of packages which have to be installed
    # in order to run a second stage at all.
    #
    # @return [Array<String>] package list
    def needed_second_stage_packages
      ret = ["autoyast2-installation"]

      # without autoyast2, <files ...> does not work
      ret << "autoyast2" if !(@current.keys & AUTOYAST_CLIENTS).empty?
      ret
    end

    # @!attribute current
    #   @return [Hash<String, Object>] current working profile
    publish variable: :current, type: "map <string, any>"
    publish variable: :ModuleMap, type: "map <string, map>"
    publish variable: :changed, type: "boolean"
    publish variable: :prepare, type: "boolean"
    publish function: :Import, type: "void (map <string, any>)"
    publish function: :Prepare, type: "void ()"
    publish function: :Reset, type: "void ()"
    publish function: :Save, type: "boolean (string)"
    publish function: :SaveSingleSections, type: "map <string, string> (string)"
    publish function: :SaveProfileStructure, type: "boolean (string)"
    publish function: :ReadProfileStructure, type: "boolean (string)"
    publish function: :ReadXML, type: "boolean (string)"
    publish function: :setElementByList, type: "map <string, any> (list, any, map <string, any>)"
    publish function: :checkProfile, type: "void ()"
    publish function: :needed_second_stage_packages, type: "list <string> ()"

  private

    def add_autoyast_packages
      @current["software"] ||= {}
      @current["software"]["packages"] ||= []
      @current["software"]["packages"] << needed_second_stage_packages
      @current["software"]["packages"].flatten!.uniq!
    end

  protected

    # Merge resource aliases in the profile
    #
    # When a resource is aliased, the configuration with the aliased name will
    # be renamed to the new name. For example, if we have a
    # services-manager.desktop file containing
    # X-SuSE-YaST-AutoInstResourceAliases=runlevel, if a "runlevel" key is found
    # in the profile, it will be renamed to "services-manager".
    #
    # The rename won't take place if a "services-manager" resource already exists.
    #
    # @see merge_aliases_map
    def merge_resource_aliases!
      resource_aliases_map.each do |alias_name, resource_name|
        aliased_config = current.delete(alias_name)
        next if aliased_config.nil? || current.key?(resource_name)

        current[resource_name] = aliased_config
      end
    end

    # Module aliases map
    #
    # This method delegates on Y2ModuleConfig#resource_aliases_map
    # and exists just to avoid a circular dependency between
    # Y2ModuleConfig and Profile (as the former depends on the latter).
    #
    # @return [Hash] Map of resource aliases where the key is the alias and the
    #                value is the resource.
    #
    # @see Y2ModuleConfigClass#resource_aliases_map
    def resource_aliases_map
      Yast.import "Y2ModuleConfig"
      Y2ModuleConfig.resource_aliases_map
    end
  end

  Profile = ProfileClass.new
  Profile.main
end
