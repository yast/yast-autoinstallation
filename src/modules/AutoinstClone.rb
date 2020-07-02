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

require "autoinstall/entries/registry"

module Yast
  # This module drives the AutoYaST cloning process
  class AutoinstCloneClass < Module
    include Yast::Logger

    def main
      Yast.import "Mode"
      Yast.import "Call"
      Yast.import "Profile"
      Yast.import "AutoinstConfig"
      Yast.import "Report"

      Yast.include self, "autoinstall/xml.rb"

      # aditional configuration resources o be cloned
      @additional = []
    end

    # Create a list of clonable resources
    #
    # @return [Array<Yast::Term>] list to be used in widgets (sorted by its label)
    def createClonableList
      clonable_items = registry.descriptions.each_with_object([]) do |description, items|
        log.debug "r: #{description.inspect}"
        next unless description.clonable?

        items << Item(Id(description.resource_name), description.translated_name)
      end

      clonable_items.sort_by { |i| i[1] }
    end

    # Builds the profile
    #
    # @param target [Symbol] How much information to include in the profile (:default, :compact)
    # @return [void] returns void and sets profile in ProfileClass.current
    # @see ProfileClass.create
    # @see ProfileClass.current for result
    # @see ProfileClass.Prepare
    def Process(target: :default)
      log.info "Additional resources: #{@additional}"
      Mode.SetMode("autoinst_config")

      registry.descriptions.each do |description|
        # Set resource name, if not using default value
        next unless @additional.include?(description.resource_name)

        time_start = Time.now
        read_module(description)
        log.info "Cloning #{description.resource_name} took: #{(Time.now - time_start).round} sec"
      end

      Call.Function("general_auto", ["Import", General()]) if @additional.include?("general")

      Profile.create(@additional, target: target)
      nil
    end

    publish variable: :additional, type: "list <string>"
    publish function: :createClonableList, type: "list ()"
    publish function: :Process, type: "void ()"

  private

    # Detects whether the current system uses multipath
    # @return [Boolean] if in use
    def multipath_in_use?
      !Y2Storage::StorageManager.instance.probed.multipaths.empty?
    end

    # General options
    #
    # @return [Hash] general options
    def General
      Yast.import "Mode"
      Mode.SetMode("normal")

      general = {}
      general["mode"] = { "confirm" => false }
      general["storage"] = { "start_multipath" => true } if multipath_in_use?

      Mode.SetMode("autoinst_config")
      general
    end

    # Reads module if it is appropriate
    #
    # @param description [Y2Autoinstallation::Entries::Description]
    # @return [void]
    def read_module(description)
      auto = description.client_name

      # Do not read settings from system in first stage, autoyast profile
      # should contain only proposed and user modified values.
      # Exception: Storage and software module have autoyast modules which are
      #            defined in autoyast itself.
      #            So, these modules have to be called.
      if !Stage.initial ||
          ["software_auto", "storage_auto"].include?(auto)
        Call.Function(auto, ["Read"])
      end
    end

    def registry
      Y2Autoinstallation::Entries::Registry.instance
    end
  end

  AutoinstClone = AutoinstCloneClass.new
  AutoinstClone.main
end
