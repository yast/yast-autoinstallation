# encoding: utf-8

# File:	clients/autoinst_storage.ycp
# Package:	Autoinstallation Configuration System
# Summary:	Storage
# Authors:	Anas Nashif<nashif@suse.de>

require "autoinstall/dialogs/storage"
require "y2storage/storage_manager"
require "y2storage/autoinst_profile/partitioning_section"

module Yast
  class StorageAutoClient < Client
    include Yast::Logger

    def main
      Yast.import "UI"
      textdomain "autoinst"


      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Storage auto started")

      Yast.import "Wizard"
      Yast.import "AutoinstPartPlan"

      Yast.import "Label"
      Yast.include self, "autoinstall/StorageDialog.rb"



      @ret = nil
      @func = ""
      @param = []

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_list?(WFM.Args(1))
          @param = Convert.to_list(WFM.Args(1))
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)



      # Import Data
      if @func == "Import"
        @ret = AutoinstPartPlan.Import(
          Convert.convert(@param, :from => "list", :to => "list <map>")
        )
        if @ret == nil
          Builtins.y2error(
            "Parameter to 'Import' is probably wrong, should be list of maps"
          )
          @ret = false
        end
        Builtins.y2milestone("Import: %1", @param)
      elsif @func == "Read"
        @ret = AutoinstPartPlan.Read
      # Create a  summary
      elsif @func == "Summary"
        @ret = AutoinstPartPlan.Summary
      # Reset configuration
      elsif @func == "Reset"
        AutoinstPartPlan.Reset
        @ret = []
      # Change configuration (run AutoSequence)
      elsif @func == "Change"
        @ret = storage_dialog.run
      # Return actual state
      elsif @func == "Export"
        @ret = AutoinstPartPlan.Export
      # Return true if modified
      elsif @func == "GetModified"
        @ret = AutoinstPartPlan.GetModified
      elsif @func == "SetModified"
        AutoinstPartPlan.SetModified
      else
        Builtins.y2error("Unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("Storage auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)

      # EOF
    end

  private

    # Returns the storage dialog
    #
    # It uses the probed storage version is available
    #
    # @return [Y2Storage::Dialogs::Storage] Storage dialog
    def storage_dialog
      manager = Y2Storage::StorageManager.instance
      partitioning =
        if manager.probed?
          Y2Storage::AutoinstProfile::PartitioningSection
            .new_from_storage(manager.probed)
        else
          Y2Storage::AutoinstProfile::PartitioningSection.new
        end
      Y2Autoinstallation::Dialogs::Storage.new(partitioning)
    end
  end
end

Yast::StorageAutoClient.new.main
