# encoding: utf-8

# File:	modules/Y2ModuleConfig.ycp
# Package:	Auto-installation
# Summary:	Read data from desktop files
# Author:	Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"

module Yast
  class Y2ModuleConfigClass < Module
    # Key for AutoYaST client name in desktop file
    RESOURCE_NAME_KEY = "X-SuSE-YaST-AutoInstResource"
    RESOURCE_NAME_MERGE_KEYS = "X-SuSE-YaST-AutoInstMerge"
    RESOURCE_ALIASES_NAME_KEY = "X-SuSE-YaST-AutoInstResourceAliases"
    MODES = %w(all configure write)
    YAST_SCHEMA_DIR ="/usr/share/YaST2/schema/autoyast/rng/*.rng"

    include Yast::Logger

    def main
      textdomain "autoinst"

      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "Profile"
      Yast.import "Installation"
      Yast.import "Desktop"
      Yast.import "Wizard"
      Yast.import "Directory"
      Yast.import "PackageSystem"

      # include "autoinstall/io.ycp";

      @GroupMap = {}
      @ModuleMap = {}

      # MenuTreeData
      # @return [Array] of modules
      @MenuTreeData = []
      Y2ModuleConfig()
    end

    # Read module configuration files
    # @return [Hash]
    def ReadMenuEntries(modes)
      modes = deep_copy(modes)
      Desktop.AgentPath = path(".autoyast2.desktop")

      _Values = [
        "Name",
        "GenericName",
        "Icon",
        "Hidden",
        "X-SuSE-YaST-AutoInst",
        RESOURCE_NAME_KEY,
        RESOURCE_ALIASES_NAME_KEY,
        "X-SuSE-YaST-AutoInstClient",
        "X-SuSE-YaST-Group",
        RESOURCE_NAME_MERGE_KEYS,
        "X-SuSE-YaST-AutoInstMergeTypes",
        "X-SuSE-YaST-AutoInstDataType",
        "X-SuSE-YaST-AutoInstClonable",
        "X-SuSE-YaST-AutoInstRequires",
        "X-SuSE-DocTeamID",
        "X-SuSE-YaST-AutoLogResource"
      ]
      Desktop.Read(_Values)
      configurations = deep_copy(Desktop.Modules)

      groups = deep_copy(Desktop.Groups)

      confs = {}

      Builtins.foreach(configurations) do |name, values|
        if Builtins.contains(
            modes,
            Ops.get_string(values, "X-SuSE-YaST-AutoInst", "")
          )
          module_auto = ""
          # determine name of client, if not default name
          if !Builtins.haskey(values, "X-SuSE-YaST-AutoInstClient") ||
              Ops.get_string(values, "X-SuSE-YaST-AutoInstClient", "") == ""
            client = Ops.add(name, "_auto")
            Builtins.y2debug("client: %1", client)
            Ops.set(values, "X-SuSE-YaST-AutoInstClient", client)
          end
          Builtins.y2debug(
            "name: %1 values: %2",
            name,
            Ops.get_string(values, "X-SuSE-YaST-AutoInstClient", "")
          )
          Ops.set(confs, name, values)
        end
      end
      [confs, groups]
    end


    # Sort tree groups
    # @param _GroupMap [Hash<String => Hash>] group map
    # @param _GroupList [Array<String>] group list
    # @return [Array]
    def SortGroups(_GroupMap, _GroupList)
      _GroupMap = deep_copy(_GroupMap)
      _GroupList = deep_copy(_GroupList)
      Builtins.sort(_GroupList) do |x, y|
        first = Ops.get_string(_GroupMap, [x, "SortKey"], "")
        second = Ops.get_string(_GroupMap, [y, "SortKey"], "")
        Ops.less_than(first, second)
      end
    end

    # Create group tree
    # @param _Groups [Hash<String => Hash>] groups
    # @return [void]
    def CreateGroupTree(_Groups)
      _Groups = deep_copy(_Groups)

      grouplist = []
      grouplist = SortGroups(_Groups, Builtins.maplist(_Groups) do |rawname, group|
        rawname
      end)

      Builtins.foreach(grouplist) do |name|
        title = Desktop.Translate(Ops.get_string(_Groups, [name, "Name"], name))
        _MeunTreeEntry = { "entry" => name, "title" => title }
        @MenuTreeData = Builtins.add(@MenuTreeData, _MeunTreeEntry)
      end
      nil
    end

    # Construct Menu Widget
    # @return [Array]
    def ConstructMenu
      CreateGroupTree(@GroupMap)

      Builtins.foreach(@ModuleMap) do |m, v|
        name = Ops.get_string(v, "Name", "")
        menu_entry = { "entry" => m, "title" => name }
        menu_list = []
        if Builtins.haskey(v, "X-SuSE-YaST-Group")
          parent = Ops.get_string(v, "X-SuSE-YaST-Group", "")
          @MenuTreeData = Builtins.maplist(@MenuTreeData) do |k|
            if Ops.get_string(k, "entry", "") == parent
              children = Ops.get_list(k, "children", [])
              children = Builtins.add(children, menu_entry)
              Ops.set(k, "children", children)
              next deep_copy(k)
            else
              next deep_copy(k)
            end
          end
        else
          @MenuTreeData = Builtins.add(@MenuTreeData, menu_entry)
        end
      end 
      nil
    end


    # Y2ModuleConfig ()
    # Constructor
    def Y2ModuleConfig
      # Read module configuration data (desktop files)
      _MenuEntries = []
      if Mode.autoinst
        _MenuEntries = ReadMenuEntries(["all", "write"])
      else
        _MenuEntries = ReadMenuEntries(["all", "configure"])
      end

      @ModuleMap = Ops.get_map(_MenuEntries, 0, {})

      Profile.ModuleMap = deep_copy(@ModuleMap)

      @GroupMap = Ops.get_map(_MenuEntries, 1, {})

      if Mode.config
        # construct the tree menu
        ConstructMenu()
      end

      nil
    end


    # Get resource name
    # @param default_resource [String] resource
    # @return [String] resource as defined in desktop file
    def getResource(default_resource)
      ret = Ops.get_string(
        @ModuleMap,
        [default_resource, RESOURCE_NAME_KEY],
        ""
      )
      if ret == ""
        return default_resource
      else
        return ret
      end
    end

    # Get resource data
    # @param [Hash] resourceMap Resource Map
    # @param resource [String] the resource
    # @return [Object] Resource Data
    def getResourceData(resourceMap, resource)
      resourceMap = deep_copy(resourceMap)
      tmp_resource = Ops.get_string(
        resourceMap,
        RESOURCE_NAME_KEY,
        ""
      )
      resource = tmp_resource if tmp_resource != ""

      data_type = Ops.get_string(
        resourceMap,
        "X-SuSE-YaST-AutoInstDataType",
        "map"
      )
      tomerge = Ops.get_string(resourceMap, RESOURCE_NAME_MERGE_KEYS, "")
      tomergetypes = Ops.get_string(
        resourceMap,
        "X-SuSE-YaST-AutoInstMergeTypes",
        ""
      )

      mergedResource = {}
      if Ops.greater_than(Builtins.size(tomerge), 0)
        _MergeTypes = Builtins.splitstring(tomergetypes, ",")
        _Merge = Builtins.splitstring(tomerge, ",")
        i = 0
        Builtins.foreach(_Merge) do |res|
          if Ops.get(_MergeTypes, i, "map") == "map"
            Ops.set(
              mergedResource,
              res,
              Builtins.eval(Ops.get_map(Profile.current, res, {}))
            )
          else
            Ops.set(
              mergedResource,
              res,
              Builtins.eval(Ops.get_list(Profile.current, res, []))
            )
          end
          i = Ops.add(i, 1)
        end
        if mergedResource == {}
          return nil
        else
          return deep_copy(mergedResource)
        end
      else
        if data_type == "map"
          if Ops.get_map(Profile.current, resource, {}) == {}
            return nil
          else
            return Builtins.eval(Ops.get_map(Profile.current, resource, {}))
          end
        else
          if Ops.get_list(Profile.current, resource, []) == []
            return nil
          else
            return Builtins.eval(Ops.get_list(Profile.current, resource, []))
          end
        end
      end
    end

    # Simple dependency resolving
    # @return [Array<Hash>]
    def Deps
      deps = {}
      m = []
      done = []
      Builtins.foreach(@ModuleMap) do |p, d|
        if Builtins.haskey(d, "X-SuSE-YaST-AutoInstRequires") &&
            Ops.get_string(d, "X-SuSE-YaST-AutoInstRequires", "") != ""
          req = Builtins.splitstring(
            Ops.get_string(d, "X-SuSE-YaST-AutoInstRequires", ""),
            ", "
          )
          req = Builtins.filter(req) { |r| r != "" }
          Ops.set(deps, p, req)
        end
      end
      Builtins.y2milestone("New dependencies: %1", deps)

      Builtins.foreach(@ModuleMap) do |p, d|
        Builtins.y2debug("done: %1", done)
        Builtins.y2debug("Working on : %1", p)
        if !Builtins.contains(done, p)
          if Builtins.haskey(deps, p)
            Builtins.foreach(Ops.get_list(deps, p, [])) do |r|
              if !Builtins.contains(done, r)
                m = Builtins.add(
                  m,
                  { "res" => r, "data" => Ops.get(@ModuleMap, r, {}) }
                )
                done = Builtins.add(done, r)
              end
            end
            m = Builtins.add(m, { "res" => p, "data" => d })
            done = Builtins.add(done, p)
          else
            m = Builtins.add(m, { "res" => p, "data" => d })
            done = Builtins.add(done, p)
          end
        end
      end

      deep_copy(m)
    end

    # Set Desktop Icon
    # @param [String] file Desktop File
    # @return [Boolean]
    def SetDesktopIcon(file)
      filename = Builtins.sformat("%1/%2.desktop", Directory.desktopdir, file)
      if Ops.less_than(SCR.Read(path(".target.size"), filename), 0)
        filename = Builtins.sformat(
          "%1/%2.desktop",
          "/usr/share/autoinstall/modules",
          file
        )
      end
      filepath = Ops.add(
        Ops.add(path(".autoyast2.desktop.v"), filename),
        path(".\"Desktop Entry\".Icon")
      )
      icon = Convert.to_string(SCR.Read(filepath))
      Builtins.y2debug("icon: %1 (%2)", icon, filepath)

      return false if icon == nil

      Wizard.SetTitleIcon(icon)
      true
    end

    # Returns list of all profile sections from the current profile, including
    # unsupported ones, that do not have any handler (AutoYaST client) assigned
    # at the current system and are not handled by AutoYaST itself.
    #
    # @return [Array<String>] of unknown profile sections
    def unhandled_profile_sections
      profile_sections = Profile.current.keys

      profile_handlers = @ModuleMap.map do |name, desc|
        if desc[RESOURCE_NAME_MERGE_KEYS]
          # The YAST module has diffent AutoYaST sections (resources).
          # e.g. Users has: users,groups,user_defaults,login_settings
          desc[RESOURCE_NAME_MERGE_KEYS].split(",")
        else
          # Taking the resource name or the plain module name.
          desc[RESOURCE_NAME_KEY] || name
        end
      end
      profile_handlers.flatten!

      profile_sections.reject! do |section|
        profile_handlers.include?(section)
      end

      # Sections which are not handled in any desktop file but the
      # corresponding clients/*_auto.rb file is available.
      # e.g. user_defaults, report, general, files, scripts
      profile_sections.reject! do |section|
        WFM.ClientExists("#{section}_auto")
      end

      # Generic sections are handled by AutoYast itself and not mentioned
      # in any desktop or clients/*_auto.rb file.
      profile_sections - Yast::ProfileClass::GENERIC_PROFILE_SECTIONS
    end

    # Returns list of all profile sections from the current profile that are
    # obsolete, e.g., we do not support them anymore.
    #
    # @return [Array<String>] of unsupported profile sections
    def unsupported_profile_sections
      unhandled_profile_sections & Yast::ProfileClass::OBSOLETE_PROFILE_SECTIONS
    end

    # Returns configuration for a given module
    #
    # @param [String] name Module name.
    # @return [Hash] Module configuration using the same structure as
    #                #Deps method (with "res" and "data" keys).
    # @see #ReadMenuEntries
    def getModuleConfig(name)
      entries = ReadMenuEntries(MODES).first # entries, groups
      entry = entries.find { |k, v| k == name } # name, entry
      if entry
        { "res" => name, "data" => entry.last }
      else
        nil
      end
    end

    # Module aliases map
    #
    # @return [Hash] Map of resource aliases where the key is the alias and the
    #                value is the resource.
    def resource_aliases_map
      ModuleMap().each_with_object({}) do |resource, map|
        name, def_resource = resource
        next if def_resource[RESOURCE_ALIASES_NAME_KEY].nil?
        resource_name = def_resource[RESOURCE_NAME_KEY] || name
        aliases = def_resource[RESOURCE_ALIASES_NAME_KEY].split(",").map(&:strip)
        aliases.each { |a| map[a] = resource_name }
      end
    end

    # Returns required package names for the given AutoYaST sections.
    #
    # @param sections [Array<String>] Section names
    # @return [Hash<String, Array<String>>] Required packages of a section.
    def required_packages(sections)
      package_names = {}
      log.info "Evaluating needed packages for handling AY-sections #{sections}"
      if PackageSystem.Installed("yast2-schema") &&
         PackageSystem.Installed("xmlstarlet")
        sections.each do |section|
          # Evaluate which *rng file belongs to the given section
          package_names[section] = []
          ret = SCR.Execute(path(".target.bash_output"),
            "/usr/bin/xml sel -t -m \"//*[@name='#{section}']\" " \
            "-f -n #{YAST_SCHEMA_DIR}")
          if ret["exit"] == 0
            ret["stdout"].split.uniq.each do |rng_file|
              # Evaluate according rnc file
              rnc_file = rng_file.gsub("rng","rnc")
              # Evalute package name to which this rnc file belongs to.
              ret = SCR.Execute(path(".target.bash_output"),
                "/bin/rpm -qf #{rnc_file} --qf \"%{NAME}\\n\"")
              if ret["exit"] == 0
                ret["stdout"].split.uniq.each do |package|
                  package_names[section] << package unless PackageSystem.Installed(package)
                end
              else
                log.info("No package belongs to #{rnc_file}.")
              end
            end
          else
            log.info("Cannot evaluate needed packages for AY section: #{section}")
          end
        end
      else
        log.info("Cannot evaluate needed packages for installation " \
          "due missing environment.")
      end
      return package_names
    end

    publish :variable => :GroupMap, :type => "map <string, map>"
    publish :variable => :ModuleMap, :type => "map <string, map>"
    publish :variable => :MenuTreeData, :type => "list <map>"
    publish :function => :Y2ModuleConfig, :type => "void ()"
    publish :function => :getResource, :type => "string (string)"
    publish :function => :getResourceData, :type => "any (map, string)"
    publish :function => :Deps, :type => "list <map> ()"
    publish :function => :SetDesktopIcon, :type => "boolean (string)"
    publish :function => :required_packages, :type => "map <string, list> (list <string>)"
    publish :function => :unhandled_profile_sections, :type => "list <string> ()"
    publish :function => :unsupported_profile_sections, :type => "list <string> ()"
  end

  Y2ModuleConfig = Y2ModuleConfigClass.new
  Y2ModuleConfig.main
end
