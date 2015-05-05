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
        "X-SuSE-YaST-AutoInstClient",
        "X-SuSE-YaST-Group",
        "X-SuSE-YaST-AutoInstMerge",
        "X-SuSE-YaST-AutoInstMergeTypes",
        "X-SuSE-YaST-AutoInstDataType",
        "X-SuSE-YaST-AutoInstClonable",
        "X-SuSE-YaST-AutoInstRequires",
        "X-SuSE-DocTeamID",
        "X-SuSE-YaST-AutoLogResource"
      ]
      Desktop.Read(_Values)
      configurations = deep_copy(Desktop.Modules)

      #y2debug("%1", configurations );
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
    # @param map<string, map> group map
    # @param list<string> group list
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
    # @param map<string, map> groups
    # @return [void]
    def CreateGroupTree(_Groups)
      _Groups = deep_copy(_Groups)
      #y2debug("Groups: %1", Groups);

      grouplist = []
      grouplist = SortGroups(_Groups, Builtins.maplist(_Groups) do |rawname, group|
        rawname
      end)

      Builtins.foreach(grouplist) do |name|
        title = Desktop.Translate(Ops.get_string(_Groups, [name, "Name"], name))
        _MeunTreeEntry = { "entry" => name, "title" => title }
        @MenuTreeData = Builtins.add(@MenuTreeData, _MeunTreeEntry)
      end

      #y2debug("data: %1", MenuTreeData);
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
      # y2debug("MenuTreeData: %1", MenuTreeData );

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
    # @param string resource
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
    # @param resrouce the resource
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
      tomerge = Ops.get_string(resourceMap, "X-SuSE-YaST-AutoInstMerge", "")
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
        desc[RESOURCE_NAME_KEY] || name
      end

      profile_sections.reject! do |section|
        profile_handlers.include?(section)
      end

      # Generic sections are handled by AutoYast itself and not mentioned
      # in any desktop file
      profile_sections - Yast::ProfileClass::GENERIC_PROFILE_SECTIONS
    end

    # Returns list of all profile sections from the current profile that are
    # obsolete, e.g., we do not support them anymore.
    #
    # @return [Array<String>] of unsupported profile sections
    def unsupported_profile_sections
      unhandled_profile_sections & Yast::ProfileClass::OBSOLETE_PROFILE_SECTIONS
    end

    publish :variable => :GroupMap, :type => "map <string, map>"
    publish :variable => :ModuleMap, :type => "map <string, map>"
    publish :variable => :MenuTreeData, :type => "list <map>"
    publish :function => :Y2ModuleConfig, :type => "void ()"
    publish :function => :getResource, :type => "string (string)"
    publish :function => :getResourceData, :type => "any (map, string)"
    publish :function => :Deps, :type => "list <map> ()"
    publish :function => :SetDesktopIcon, :type => "boolean (string)"
    publish :function => :unhandled_profile_sections, :type => "list <string> ()"
    publish :function => :unsupported_profile_sections, :type => "list <string> ()"
  end

  Y2ModuleConfig = Y2ModuleConfigClass.new
  Y2ModuleConfig.main
end
