# File:  modules/Y2ModuleConfig.ycp
# Package:  Auto-installation
# Summary:  Read data from desktop files
# Author:  Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"

module Yast
  class Y2ModuleConfigClass < Module
    # Key for AutoYaST client name in desktop file
    RESOURCE_NAME_KEY = "X-SuSE-YaST-AutoInstResource".freeze
    RESOURCE_NAME_MERGE_KEYS = "X-SuSE-YaST-AutoInstMerge".freeze
    RESOURCE_ALIASES_NAME_KEY = "X-SuSE-YaST-AutoInstResourceAliases".freeze
    MODES = %w[all configure write].freeze
    YAST_SCHEMA_DIR = "/usr/share/YaST2/schema/autoyast/rng/*.rng".freeze
    SCHEMA_PACKAGE_FILE = "/usr/share/YaST2/schema/autoyast/rnc/includes.rnc".freeze

    ALWAYS_CLONABLE_MODULES ||= ["software", "partitioning", "bootloader"].freeze

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

      @GroupMap = {}
      @ModuleMap = {}

      Y2ModuleConfig()
    end

    # Y2ModuleConfig ()
    # Constructor
    def Y2ModuleConfig
      # Read module configuration data (desktop files)
      _MenuEntries = []
      _MenuEntries = if Mode.autoinst
        ReadMenuEntries(["all", "write"])
      else
        ReadMenuEntries(["all", "configure"])
      end

      @ModuleMap = Ops.get_map(_MenuEntries, 0, {})

      @GroupMap = Ops.get_map(_MenuEntries, 1, {})

      nil
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
                  "res" => r, "data" => Ops.get(@ModuleMap, r, {})
                )
                done = Builtins.add(done, r)
              end
            end
          end
          m = Builtins.add(m, "res" => p, "data" => d)
          done = Builtins.add(done, p)
        end
      end

      deep_copy(m)
    end

    # Returns configuration for a given module
    #
    # @param [String] name Module name.
    # @return [Hash] Module configuration using the same structure as
    #                #Deps method (with "res" and "data" keys).
    # @see #ReadMenuEntries
    def getModuleConfig(name)
      entries = ReadMenuEntries(MODES).first # entries, groups
      entry = entries.find { |k, _v| k == name } # name, entry
      { "res" => name, "data" => entry.last } if entry
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
      if File.exist?(SCHEMA_PACKAGE_FILE)
        sections.each do |section|
          # Evaluate which *rng file belongs to the given section
          package_names[section] = []
          ret = SCR.Execute(path(".target.bash_output"),
            "/usr/bin/grep -l \"<define name=\\\"#{section}\\\">\" #{YAST_SCHEMA_DIR}")
          if ret["exit"] == 0
            ret["stdout"].split.uniq.each do |rng_file|
              # Evalute package name to which this rng file belongs to.
              package = package_name_of_schema(File.basename(rng_file, ".rng"))
              if package
                package_names[section] << package unless PackageSystem.Installed(package)
              else
                log.info("No package belongs to #{rng_file}.")
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
      package_names
    end

    def clonable_modules
      ModuleMap().select do |name, resource_map|
        clonable = resource_map["X-SuSE-YaST-AutoInstClonable"] == "true"
        clonable || ALWAYS_CLONABLE_MODULES.include?(name)
      end
    end
    publish variable: :GroupMap, type: "map <string, map>"
    publish variable: :ModuleMap, type: "map <string, map>"
    publish function: :Deps, type: "list <map> ()"
    publish function: :required_packages, type: "map <string, list> (list <string>)"

  private

    # Returns package name of a given schema.
    # This information is stored in /usr/share/YaST2/schema/autoyast/rnc/includes.rnc
    # which will be provided by the yast2-schema package.
    #
    # @param schema <String> schema name like firewall, firstboot, ...
    # @return <String> package name or nil
    def package_name_of_schema(schema)
      if !@schema_package
        @schema_package = {}
        File.readlines(SCHEMA_PACKAGE_FILE).each do |line|
          line_split = line.split
          next if line.split.size < 4 # Old version of yast2-schema

          @schema_package[File.basename(line_split[1].delete("\'"), ".rnc")] = line.split.last
        end
      end
      @schema_package[schema]
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
  end

  Y2ModuleConfig = Y2ModuleConfigClass.new
  Y2ModuleConfig.main
end
