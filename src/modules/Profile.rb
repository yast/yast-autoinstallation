# File:  modules/Profile.ycp
# Module:  Auto-Installation
# Summary:  Profile handling
# Authors:  Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"
require "yast2/popup"

require "fileutils"

require "autoinstall/entries/registry"
require "installation/autoinst_profile/element_path"
require "ui/password_dialog"

module Yast
  class ProfileHash < Hash
    # replace Hash -> ProfileHash recursively
    def initialize(x = {})
      x.each_pair do |key, value|
        if value.is_a?(Hash)
          self[key] = ProfileHash.new(value)
        else
          self[key] = value
        end
      end
    end

    # with an explicit default it's possible to check for the presence of an
    # element vs. empty element
    def fetch_as(x, type, default = nil)
      tmp = self.fetch(x, nil)
      if !tmp.is_a?(type)
        if default.is_a?(Hash)
          tmp = ProfileHash.new(default)
        else
          tmp = default
        end
      end
      tmp
    end
  end

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

      Yast.import "AutoinstConfig"
      Yast.import "AutoinstFunctions"
      Yast.import "Directory"
      Yast.import "GPG"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "ProductControl"
      Yast.import "Stage"
      Yast.import "XML"

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

      @current = ::Yast::ProfileHash.new(@current)
      log.debug "Current Profile = #{@current}"

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
      Builtins.y2debug("Saving data (%1) to XML file %2", @current, file)
      XML.YCPToXMLFile(:profile, @current, file)

      if AutoinstConfig.ProfileEncrypted
        if [nil, ""].include?(AutoinstConfig.ProfilePassword)
          password = ::UI::PasswordDialog.new(
            _("Password for encrypted AutoYaST profile"), confirm: true
          ).run
          return false unless password

          AutoinstConfig.ProfilePassword = password
        end
        dir = SCR.Read(path(".target.tmpdir"))
        target_file = File.join(dir, "encrypted_autoyast.xml")
        GPG.encrypt_symmetric(file, target_file, AutoinstConfig.ProfilePassword)
        ::FileUtils.mv(target_file, file)
      end

      true
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
      if !GPG.encrypted_symmetric?(file)
        content = File.read(file)
      else
        AutoinstConfig.ProfileEncrypted = true
        label = _("Encrypted AutoYaST profile.")

        begin
          if AutoinstConfig.ProfilePassword.empty?
            pwd = ::UI::PasswordDialog.new(label).run
            return false unless pwd
          else
            pwd = AutoinstConfig.ProfilePassword
          end

          content = GPG.decrypt_symmetric(file, pwd)
          AutoinstConfig.ProfilePassword = pwd
        rescue GPGFailed => e
          res = Yast2::Popup.show(_("Decryption of profile failed."),
            details: e.message, headline: :error, buttons: :continue_cancel)
          if res == :continue
            retry
          else
            return false
          end
        end
      end
      @current = XML.XMLToYCPString(content)

      # FIXME: rethink and check for sanity of that!
      # save decrypted profile for modifying pre-scripts
      if Stage.initial
        SCR.Write(
          path(".target.string"),
          file,
          content
        )
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

    # Returns a profile merging the given value into the specified path
    #
    # The path can be a String or a Installation::AutoinstProfile::ElementPath
    # object. Although the real work is performed by {setElementByList}, it is
    # usually preferred to use this method as it takes care of handling the
    # path.
    #
    # @example Set a value using a XPath-like path
    #   path = "//a/b"
    #   set_element_by_path(path, 1, {}) #=> { "a" => { "b" => 1 } }
    #
    # @example Set a value using an ask-list style path
    #   path = "users,0,username"
    #   set_element_by_path(path, "root", {}) #=> { "users" => [{"username" => "root"}] }
    #
    # @param path [ElementPath,String] Profile path or string representing the path
    # @param value [Object] Value to write
    # @param profile [Hash] Initial profile
    # @return [Hash] Modified profile
    def set_element_by_path(path, value, profile)
      profile_path =
        if path.is_a?(::String)
          ::Installation::AutoinstProfile::ElementPath.from_string(path)
        else
          path
        end
      setElementByList(profile_path.to_a, value, profile)
    end

    # Returns a profile merging the given value into the specified path
    #
    # The given profile is not modified.
    #
    # This method is a replacement for this YCP code:
    #      list<any> l = [ "key1",0,"key3" ];
    #      m[ l ] = v;
    #
    # @example Set a value
    #   path = ["a", "b"]
    #   setElementByList(path, 1, {}) #=> { "a" => { "b" => 1 } }
    #
    # @example Add an element to an array
    #   path = ["users", 0, "username"]
    #   setElementByList(path, "root", {}) #=> { "users" => [{"username" => "root"}] }
    #
    # @example Beware of the gaps!
    #   path = ["users", 1, "username"]
    #   setElementByList(path, "root", {}) #=> { "users" => [nil, {"username" => "root"}] }
    #
    # @param path [Array<String,Integer>] Element's path
    # @param value [Object] Value to write
    # @param profile [Hash] Initial profile
    # @return [Hash] Modified profile
    def setElementByList(path, value, profile)
      profile = deep_copy(profile)
      merge_element_by_list(path, value, profile)
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

    # @see setElementByList
    def merge_element_by_list(path, value, profile)
      current, *remaining_path = path
      current_value =
        if remaining_path.empty?
          value
        elsif remaining_path.first.is_a?(::String)
          merge_element_by_list(remaining_path, value, profile[current] || {})
        else
          merge_element_by_list(remaining_path, value, profile[current] || [])
        end
      log.debug("Setting #{current} to #{current_value.inspect}")
      profile[current] = current_value
      profile
    end
  end

  Profile = ProfileClass.new
  Profile.main
end
