# encoding: utf-8

# File:
#   modules/AutoinstClone.ycp
#
# Package:
#   Autoinstallation Configuration System
#
# Summary:
#   Create a control file from an exisiting machine
#
# Authors:
#   Anas Nashif <nashif@suse.de>
#
# $Id$
#
#
require "yast"
require "y2storage"

module Yast
  class AutoinstCloneClass < Module
    include Yast::Logger

    def main
      Yast.import "Mode"

      Yast.import "XML"
      Yast.import "Call"
      Yast.import "Profile"
      Yast.import "Y2ModuleConfig"
      Yast.import "Misc"
      Yast.import "AutoinstConfig"
      Yast.import "Report"

      Yast.include self, "autoinstall/xml.rb"

      @Profile = {}
      @bytes_per_unit = 0

      # spceial treatment for base resources
      @base = []

      # aditional configuration resources o be cloned
      @additional = []
    end

    # Detects whether the current system uses multipath
    # @return [Boolean] if in use
    def multipath_in_use?
      !Y2Storage::StorageManager.instance.probed.multipaths.empty?
    end

    # General options
    # @return [Hash] general options
    def General
      Yast.import "Mode"
      Mode.SetMode("normal")

      general = {}

      general["mode"] = { "confirm" => false }

      general["signature-handling"] = {
        "accept_unsigned_file"         => true,
        "accept_file_without_checksum" => true,
        "accept_unknown_gpg_key"       => true,
        "accept_verification_failed"   => false,
        "import_gpg_key"               => true,
        "accept_non_trusted_gpg_key"   => true
      }
      general["storage"] = {
        "start_multipath" => multipath_in_use?
      }

      Mode.SetMode("autoinst_config")
      general
    end

    # Clone a Resource
    # @param resource    [String] resource
    # @param resourceMap [Hash] resources map
    # @return [Array]
    def CommonClone(resource, resourceMap)
      resourceMap = deep_copy(resourceMap)
      data_type = Ops.get_string(
        resourceMap,
        "X-SuSE-YaST-AutoInstDataType",
        "map"
      )
      auto = Ops.get_string(resourceMap, "X-SuSE-YaST-AutoInstClient", "")
      resource = Ops.get_string(
        resourceMap,
        "X-SuSE-YaST-AutoInstResource",
        resource
      )

      # Do not read settings from system in first stage, autoyast profile
      # should contain only proposed and user modified values.
      # Exception: Storage and software module have autoyast modules which are
      #            defined in autoyast itself.
      #            So, these modules have to be called.
      if !Stage.initial ||
          ["software_auto", "storage_auto"].include?(auto)
        Call.Function(auto, ["Read"])
      end
      # Flagging YAST module for export
      Call.Function(auto, ["SetModified"])

      true
    end

    # Create a list of clonable resources
    # @return [Array] list to be used in widgets
    def createClonableList
      items = []
      Builtins.foreach(Y2ModuleConfig.ModuleMap) do |def_resource, resourceMap|
        Builtins.y2debug(
          "r: %1 => %2",
          def_resource,
          Ops.get_string(resourceMap, "X-SuSE-YaST-AutoInstClonable", "false")
        )
        clonable = Ops.get_string(
          resourceMap,
          "X-SuSE-YaST-AutoInstClonable",
          "false"
        ) == "true"
        if clonable || "partitioning" == def_resource ||
            "software" == def_resource || # has no desktop file
            "bootloader" == def_resource # has no desktop file
          desktop_file = Builtins.substring(
            Ops.get_string(resourceMap, "X-SuSE-DocTeamID", ""),
            4
          )
          name = Builtins.dpgettext(
            "desktop_translations",
            "/usr/share/locale/",
            Ops.add(
              Ops.add(Ops.add("Name(", desktop_file), ".desktop): "),
              Ops.get_string(resourceMap, "Name", "")
            )
          )
          if name ==
              Ops.add(
                Ops.add(Ops.add("Name(", desktop_file), ".desktop): "),
                Ops.get_string(resourceMap, "Name", "")
              )
            name = Ops.get_string(resourceMap, "Name", "")
          end
          # Set resource name, if not using default value
          resource = Ops.get_string(
            resourceMap,
            "X-SuSE-YaST-AutoInstResource",
            ""
          )
          resource = def_resource if resource == ""
          items = if resource != ""
            Builtins.add(items, Item(Id(resource), name))
          else
            Builtins.add(items, Item(Id(def_resource), name))
          end
        end
      end
      # sort items for nicer display
      items = Builtins.sort(
        Convert.convert(items, from: "list", to: "list <term>")
      ) do |x, y|
        Ops.less_than(Ops.get_string(x, 1, "x"), Ops.get_string(y, 1, "y"))
      end
      deep_copy(items)
    end

    # Build the profile
    # @return [void]
    def Process
      log.info "Base resources: #{@base} additional: #{@additional}"
      Profile.Reset
      Profile.prepare = true
      Mode.SetMode("autoinst_config")

      Builtins.foreach(Y2ModuleConfig.ModuleMap) do |def_resource, resourceMap|
        # Set resource name, if not using default value
        resource = Ops.get_string(
          resourceMap,
          "X-SuSE-YaST-AutoInstResource",
          ""
        )
        resource = def_resource if resource == ""

        if @additional.include?(resource)
          log.info "Now cloning: #{resource}"
          time_start = Time.now
          ret = CommonClone(def_resource, resourceMap)
          log.info "Cloning #{resource} took: #{(Time.now - time_start).round} sec"
        end
      end

      Call.Function("general_auto", ["Import", General()])
      Call.Function("general_auto", ["SetModified"])

      Call.Function("report_auto", ["Import", Report.Export])
      Call.Function("report_auto", ["SetModified"])

      Profile.Prepare
      nil
    end

    # Write the profile to a defined path
    # @param [String] outputFile Output file path
    # @return [Boolean] true on success
    def Write(outputFile)
      Process()
      ret = Profile.Save(outputFile)
      ret
    end

    # Export profile, Used only from within autoyast2
    # @return [void]
    def Export
      Yast.import "Profile"
      Profile.Reset
      Process()
      nil
    end

    publish variable: :Profile, type: "map"
    publish variable: :base, type: "list <string>"
    publish variable: :additional, type: "list <string>"
    publish function: :General, type: "map ()"
    publish function: :createClonableList, type: "list ()"
    publish function: :Process, type: "void ()"
    publish function: :Write, type: "boolean (string)"
    publish function: :Export, type: "void ()"
  end

  AutoinstClone = AutoinstCloneClass.new
  AutoinstClone.main
end
