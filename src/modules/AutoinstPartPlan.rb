# File:  modules/AutoinstCommon.ycp
# Package:  Auto-installation/Partition
# Summary:  Module representing a partitioning plan
# Author:  Sven Schober (sschober@suse.de)
#
# $Id: AutoinstPartPlan.ycp 2813 2008-06-12 13:52:30Z sschober $
require "yast"
require "y2storage"
require "autoinstall/presenters/drive"

module Yast
  class AutoinstPartPlanClass < Module
    include Yast::Logger

    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.include self, "autoinstall/common.rb"
      Yast.include self, "autoinstall/tree.rb"

      Yast.import "AutoinstCommon"
      Yast.import "Summary"
      Yast.import "Popup"
      Yast.import "Mode"
      Yast.import "Arch"

      # The general idea with this moduls is that it manages a single
      # partition plan (@plan) and the user can work on that
      # plan without having to specify that variable on each method
      # call.
      # This is on the one hand convenient for the user and on the
      # other hand we have control over the plan.

      # PRIVATE

      # The single plan instance managed by this module.
      #
      # The partition plan is technically a list of DriveT'.
      Reset()

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

    # PUBLIC INTERFACE

    # INTER FACE TO CONF TREE

    # Return summary of configuration
    #
    # @return  [String] configuration summary dialog
    def Summary
      summary = ""
      summary = Summary.AddHeader(summary, _("Drives"))
      if @plan.drives.empty?
        summary = Summary.AddLine(summary,
          _("Not yet cloned."))
      else
        # We are counting harddisks only (type CT_DISK)
        num = @plan.drives.size
        summary = Summary.AddLine(
          summary,
          (n_("%s drive in total", "%s drives in total", num) % num)
        )
        summary = Summary.OpenList(summary)
        @plan.drives.each do |drive|
          presenter = Y2Autoinstallation::Presenters::Drive.new(drive)
          summary = Summary.AddListItem(summary, presenter.ui_label)
          summary = Summary.OpenList(summary)
          presenter.partitions.each do |part|
            summary = Summary.AddListItem(summary, part.ui_label)
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
    # @param settings [Array<Hash>,Y2Storage::AutoinstProfile::PartitioningSection]
    #   An array of hashes describing each drive or a partitioning section object
    # @return  [Boolean] success
    def Import(settings)
      log.info("entering Import with #{settings.inspect}")

      @plan =
        if settings.is_a?(Y2Storage::AutoinstProfile::PartitioningSection)
          settings
        else
          Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(settings || [])
        end

      true
    end

    # Gets the probed partitioning from the storage manager
    def Read
      devicegraph = Y2Storage::StorageManager.instance.probed
      @plan = Y2Storage::AutoinstProfile::PartitioningSection.new_from_storage(devicegraph)
      true
    end

    # Dump the settings to a map, for autoinstallation use.
    #
    # @return [Array<Hash>]
    def Export
      log.info("entering Export with #{@plan.inspect}")
      drives = @plan.to_hashes

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
      @plan = Y2Storage::AutoinstProfile::PartitioningSection.new
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
