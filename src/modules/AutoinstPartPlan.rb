# File:  modules/AutoinstCommon.ycp
# Package:  Auto-installation/Partition
# Summary:  Module representing a partitioning plan
# Author:  Sven Schober (sschober@suse.de)
#
# $Id: AutoinstPartPlan.ycp 2813 2008-06-12 13:52:30Z sschober $
require "yast"
require "y2storage"

module Yast
  class AutoinstPartPlanClass < Module
    include Yast::Logger

    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.include self, "autoinstall/types.rb"
      Yast.include self, "autoinstall/common.rb"
      Yast.include self, "autoinstall/tree.rb"

      Yast.import "AutoinstCommon"
      Yast.import "Summary"
      Yast.import "Popup"
      Yast.import "Mode"
      Yast.import "Arch"

      # The general idea with this moduls is that it manages a single
      # partition plan (AutoPartPlan) and the user can work on that
      # plan without having to sepcify that variable on each method
      # call.
      # This is on the one hand convenient for the user and on the
      # other hand we have control over the plan.

      # PRIVATE

      # The single plan instance managed by this module.
      #
      # The partition plan is technically a list of DriveT'.
      @AutoPartPlan = []

      # default value of settings modified
      @modified = false

      # Devices which do not have any mount point, lvm_group or raid_name
      # These devices will not be taken in the AutoYaSt configuration file
      # but will be added to the skip_list in order not regarding it while
      # next installation. (bnc#989392)
      @skipped_devices = []
    end

    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      Builtins.y2milestone("SetModified")
      @modified = true

      nil
    end

    # Functions which returns if the settings were modified
    #
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end

    # Create a partition plan for the calling client
    # @return [Array] partition plan
    def ReadHelper
      devicegraph = Y2Storage::StorageManager.instance.probed
      profile = Y2Storage::AutoinstProfile::PartitioningSection.new_from_storage(devicegraph)
      profile.to_hashes
    end

    # PUBLIC INTERFACE

    # INTER FACE TO CONF TREE

    # Return summary of configuration
    # @return  [String] configuration summary dialog
    def Summary
      summary = ""
      summary = Summary.AddHeader(summary, _("Drives"))
      if @AutoPartPlan.empty?
        summary = Summary.AddLine(summary,
          _("Not yet cloned."))
      else
        # We are counting harddisks only (type CT_DISK)
        num = @AutoPartPlan.count { |drive| drive["type"] == :CT_DISK }
        summary = Summary.AddLine(
          summary,
          (n_("%s drive in total", "%s drives in total", num) % num)
        )
        summary = Summary.OpenList(summary)
        Builtins.foreach(@AutoPartPlan) do |drive|
          driveDesc = AutoinstDrive.getNodeName(drive, true)
          summary = Summary.AddListItem(summary, driveDesc)
          summary = Summary.OpenList(summary)
          Builtins.foreach(Ops.get_list(drive, "partitions", [])) do |part|
            summary = Summary.AddListItem(
              summary,
              AutoinstPartition.getPartitionDescription(part, true)
            )
          end
          summary = Summary.CloseList(summary)
          summary = Summary.AddNewLine(summary)
        end
        summary = Summary.CloseList(summary)
      end
      summary
    end

    # Get all the configuration from a map.
    # When called by inst_auto<module name> (preparing autoinstallation data)
    # the list may be empty.
    # @param [Array<Hash>] settings a list  [...]
    # @return  [Boolean] success
    def Import(settings)
      log.info("entering Import with #{settings.inspect}")
      # index settings
      @AutoPartPlan = settings.map.with_index { |d, i| d.merge("_id" => i) }
      # set default value
      @AutoPartPlan.each do |d|
        d["initialize"] = false unless d.key?("initialize")
      end
      true
    end

    def Read
      Import(ReadHelper())
    end

    # Dump the settings to a map, for autoinstallation use.
    # @return [Array]
    def Export
      log.info("entering Export with #{@AutoPartPlan.inspect}")
      drives = deep_copy(@AutoPartPlan)
      drives.each { |d| d.delete("_id") }

      # Adding skipped devices to partitioning section.
      # These devices will not be taken in the AutoYaSt configuration file
      # but will be added to the skip_list in order not regarding it while
      # next installation. (bnc#989392)
      unless @skipped_devices.empty?
        skip_device = {}
        skip_device["initialize"] = true
        skip_device["skip_list"] = @skipped_devices.collect do |dev|
          { "skip_key" => "device", "skip_value" => dev }
        end
        drives << skip_device
      end

      drives
    end

    def Reset
      @AutoPartPlan = []

      nil
    end

    publish function: :SetModified, type: "void ()"
    publish function: :GetModified, type: "boolean ()"
    publish function: :updateTree, type: "void ()"
    publish function: :Summary, type: "string ()"
    publish function: :Import, type: "boolean (list <map>)"
    publish function: :Read, type: "boolean ()"
    publish function: :Export, type: "list <map> ()"
    publish function: :Reset, type: "void ()"
  end

  AutoinstPartPlan = AutoinstPartPlanClass.new
  AutoinstPartPlan.main
end
