# File:  modules/Profile.ycp
# Module:  Auto-Installation
# Summary:  Profile handling
# Authors:  Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"
require "yast2/popup"

require "autoinstall/entries/registry"

module Yast
  class ProfileClass < Module
    include Yast::Logger

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
      generalCompat # compatibility to new language,keyboard and timezone (SL10.1)
      softwareCompat

      Builtins.y2debug("Current Profile=%1", @current)
      nil
    end

    # Prepare Profile for saving and remove empty data structs
    # This is mainly for editing profile when there is some parts we do not write ourself
    # For creating new one from given set of modules see {#create}
    #
    # @param target [Symbol] How much information to include in the profile (:default, :compact)
    # @return [void]
    def Prepare(target: :default)
      return if !@prepare

      Popup.ShowFeedback(
        _("Collecting configuration data..."),
        _("This may take a while")
      )

      edit_profile(target: target)

      Popup.ClearFeedback
      @prepare = false
      nil
    end

    # Sets Profile#current to exported values created from given set of modules
    # @param target [Symbol] How much information to include in the profile (:default, :compact)
    # @return [Hash] value set to Profile#current
    def create(modules, target: :default)
      Popup.Feedback(
        _("Collecting configuration data..."),
        _("This may take a while")
      ) do
        @current = {}
        edit_profile(modules, target: target)
      end

      @current
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
        XML.YCPToXMLFile(:profile, @current, file)
        ret = true
      end
      ret
    rescue XMLSerializationError => e
      log.error "Failed to serialize objects: #{e.inspect}"
      false
    end

    # Save sections of current profile to separate files
    #
    # @param [String] dir - directory to store section xml files in
    # @return [Hash<String,String>] returns map with section name and respective file where
    #   it is serialized
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
        begin
          XML.YCPToXMLFile(:profile, tmpProfile, sectionFileName)
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
        rescue XMLSerializationError => e
          log.error "Could not write section #{sectionName} to file #{sectionFileName}:" \
            "#{e.inspect}"
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

      Import(@current)
      true
    rescue Yast::XMLDeserializationError => e
      # autoyast has read the autoyast configuration file but something went wrong
      message = _(
        "The XML parser reported an error while parsing the autoyast profile. " \
          "The error message is:\n"
      )
      message += e.message
      log.info "xml parsing error #{e.inspect}"
      Yast2::Popup.show(message, headline: :error)
      false
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

    # @deprecated Unused, removed
    def checkProfile
      log.warn("Profile.checkProfile() is obsolete, do not use it")
      log.warn("Called from #{caller(1).first}")
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
      reg = Y2Autoinstallation::Entries::Registry.instance
      alias_map = reg.descriptions.each_with_object({}) do |d, r|
        d.aliases.each { |a| r[a] = d.resource_name || d.name }
      end
      alias_map.each do |alias_name, resource_name|
        aliased_config = current.delete(alias_name)
        next if aliased_config.nil? || current.key?(resource_name)

        current[resource_name] = aliased_config
      end
    end

    # Edits profile for given modules. If nil is passed, it used GetModfied method.
    def edit_profile(modules = nil, target: :default)
      registry = Y2Autoinstallation::Entries::Registry.instance
      registry.descriptions.each do |description|
        #
        # Set resource name, if not using default value
        #
        resource = description.resource_name
        tomerge = description.managed_keys
        module_auto = description.client_name
        export = if modules
          modules.include?(resource) || modules.include?(description.name)
        else
          WFM.CallFunction(module_auto, ["GetModified"])
        end
        next unless export

        resource_data = WFM.CallFunction(module_auto, ["Export", "target" => target.to_s])

        if tomerge.size < 2
          s = (resource_data || {}).size
          if s > 0
            @current[resource] = resource_data
          else
            @current.delete(resource)
          end
        else
          tomerge.each do |res|
            value = resource_data[res]
            if !value
              log.warn "key #{res} expected to be exported from #{resource}"
              next
            end
            # FIXME: no deleting for merged keys, is it correct?
            @current[res] = value unless value.empty?
          end
        end
      end
    end
  end

  Profile = ProfileClass.new
  Profile.main
end
