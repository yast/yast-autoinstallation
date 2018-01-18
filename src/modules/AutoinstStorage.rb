# encoding: utf-8

# File:	modules/AutoinstStorage.ycp
# Module:	Auto-Installation
# Summary:	Storage
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"
require "autoinstall/storage_proposal"
require "autoinstall/dialogs/question"
require "autoinstall/storage_proposal_issues_presenter"
require "autoinstall/partitioning_preprocessor"

module Yast
  class AutoinstStorageClass < Module

    include Yast::Logger

    # @return [Hash] General settings (from +storage/general+ profile section)
    attr_accessor :general_settings

    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.import "RootPart"
      Yast.import "Summary"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "Mode"
      Yast.import "Installation"

      # All shared data are in yast2.rpm to break cyclic dependencies
      Yast.import "AutoinstData"

      # Read existing fstab and format partitions, but dont create anything
      # Use same mountpoints etc.
      @read_fstab = false

      # Fstab options
      @fstab = {}

      # general/storage settings
      self.general_settings = {}

      Yast.include self, "autoinstall/autoinst_dialogs.rb"
    end

    # Get all the configuration from a map.
    #
    # When called by inst_auto<module name> (preparing autoinstallation data)
    # the list may be empty.
    #
    # @param  settings [Array<Hash>] Profile settings (list of drives for custom partitioning)
    # @return [Boolean] success
    def Import(settings)
      log.info "entering Import with #{settings.inspect}"
      partitioning = preprocessed_settings(settings)
      return false unless partitioning

      build_proposal(partitioning)
    end

    # Import settings from the general/storage section
    #
    # General settings are imported with a different method because:
    #
    # * It used to happen before with the old libstorage, so we'll
    #   keep it until multipath support is implemented.
    # * To do not modify Import list of parameters (we would need
    #   to use a hash instead of a list of hashes) to retain backward
    #   compatibility.
    #
    # @param settings [Hash] general/storage section settings
    def import_general_settings(settings)
      return if settings.nil?

      self.general_settings = settings.clone

      # Backward compatibility
      if general_settings["btrfs_set_default_subvolume_name"] == false
        general_settings["btrfs_default_subvolume"] = ""
      end
      general_settings.delete("btrfs_set_default_subvolume_name")

      # Override product settings from control file
      Yast::ProductFeatures.SetSection("partitioning", general_settings)
    end

    # Import Fstab data
    # @param [Hash] settings Settings Map
    # @return	[Boolean] true on success
    def ImportAdvanced(settings)
      settings = deep_copy(settings)
      log.info "entering ImportAdvanced with #{settings}"
      @fstab = Ops.get_map(settings, "fstab", {})
      @read_fstab = Ops.get_boolean(@fstab, "use_existing_fstab", false)
      true
    end

    # Export general settings
    #
    # @return [Hash] General settings
    def export_general_settings
      # Do not export nil settings
      general_settings.reject { |_key, value| value.nil? }
    end

    # Moved here from RootPart module (used just by this module)
    def SetFormatPartitions(fstabpart)
# storage-ng
=begin
      fstabpart = deep_copy(fstabpart)
      # All storage devices
      target_map = Storage.GetTargetMap

      # all activated
      tmp = Builtins.filter(RootPart.GetActivated) do |e|
        Ops.get_string(e, :type, "") == "mount" ||
          Ops.get_string(e, :type, "") == "swap"
      end

      Builtins.foreach(tmp) do |e|
        mntpt = Ops.get_string(e, :type, "") == "swap" ?
          "swap" :
          Ops.get_string(e, :mntpt, "")
        part = Ops.get_string(e, :device, "")
        p = {}
        Builtins.foreach(fstabpart) do |pp|
          # mountpoint matches
          if Ops.get_string(pp, "mount", "") == mntpt
            p = deep_copy(pp)
            raise Break
          end
        end
        mount_options = ""
        Builtins.foreach(Storage.ReadFstab(Installation.destdir)) do |entry|
          if Ops.get_string(entry, "file", "") == mntpt
            mount_options = Ops.get_string(entry, "mntops", "")
            raise Break
          end
        end
        target_map = Storage.SetPartitionData(target_map, part, "mount", mntpt)
        target_map = Storage.SetPartitionData(
          target_map,
          part,
          "format",
          Ops.get_boolean(p, "format", false)
        )
        target_map = Storage.SetPartitionData(target_map, part, "delete", false)
        target_map = Storage.SetPartitionData(target_map, part, "create", false)
        if Builtins.haskey(p, "filesystem")
          target_map = Storage.SetPartitionData(
            target_map,
            part,
            "filesystem",
            Ops.get_symbol(p, "filesystem", :ext4)
          )
        end
        if Ops.greater_than(Builtins.size(mount_options), 0) &&
            !Builtins.haskey(p, "fstopt")
          target_map = Storage.SetPartitionData(
            target_map,
            part,
            "fstopt",
            mount_options
          )
        end
        if Builtins.haskey(p, "fstopt")
          target_map = Storage.SetPartitionData(
            target_map,
            part,
            "fstopt",
            Ops.get_string(p, "fstopt", "")
          )
        end
        if Builtins.haskey(p, "mountby")
          target_map = Storage.SetPartitionData(
            target_map,
            part,
            "mountby",
            Ops.get_symbol(p, "mountby", :device)
          )
        end
      end

      Storage.SetTargetMap(target_map)
=end
      true
    end

    # Handle /etc/fstab usage
    # @return [Boolean]
    def handle_fstab
      log.info "entering handle_fstab"

      if !RootPart.didSearchForRootPartitions
        UI.OpenDialog(
          Opt(:decorated),
          Label(_("Evaluating root partition. One moment please..."))
        )
        RootPart.FindRootPartitions
        UI.CloseDialog
      end

      if RootPart.numberOfValidRootPartitions == 0
        # a popup
        Popup.Message(_("No Linux root partition found."))
        return false
      end

      # We must only change RootPart::selectedRootPartition if booting
      # is inevitable.
       rp = Ops.get_string(@fstab, "root_partition", "")
      fstab_partitions = Ops.get_list(@fstab, "partitions", [])

      if RootPart.numberOfValidRootPartitions == 1
        RootPart.SetSelectedToValid
      elsif rp == ""
        Popup.Message(
          _(
            "Multiple root partitions found, but you did not configure\nwhich root partition should be used.  Automatic installation not possible.\n"
          )
        )
        return false
      elsif Builtins.haskey(RootPart.rootPartitions, rp) &&
          Ops.greater_than(RootPart.numberOfValidRootPartitions, 1)
        RootPart.selectedRootPartition = rp
      end

      RootPart.MountPartitions(RootPart.selectedRootPartition)
      SetFormatPartitions(fstab_partitions)
      RootPart.UnmountPartitions(true)
      true
    end


    # Create partition plan
    # @return [Boolean]
    def Write
      return handle_fstab if @read_fstab
      true
    end

    publish :variable => :read_fstab, :type => "boolean"
    publish :variable => :fstab, :type => "map"
    publish :function => :Import, :type => "boolean (list <map>)"
    publish :function => :ImportAdvanced, :type => "boolean (map)"
    publish :function => :Write, :type => "boolean ()"

  private

    # Build the storage proposal if possible
    #
    # @param  partitioning [Array<Hash>] Profile settings (list of drives for custom partitioning)
    # @return [Boolean] success
    def build_proposal(partitioning)
      proposal = Y2Autoinstallation::StorageProposal.new(partitioning)
      if valid_proposal?(proposal)
        log.info "Saving successful proposal: #{proposal.inspect}"
        proposal.save
        true
      else # not needed
        log.warn "Failed proposal: #{proposal.inspect}"
        false
      end
    end

    # Determine whether the proposal is valid and inform the user if not valid
    #
    # When proposal is not valid:
    #
    # * If it only contains warnings: asks the user for confirmation.
    # * If it contains some important problem, inform the user.
    #
    # @param proposal [StorageProposal] Storage proposal to check
    # @return [Boolean] True if the proposal is valid or the user accepted an invalid one.
    def valid_proposal?(proposal)
      return true if proposal.valid?

      report_settings = Report.Export
      if proposal.issues_list.fatal?
        # On fatal errors, the message should be displayed and without timeout
        level = :error
        buttons_set = :abort
        display_message = true
        log_message = report_settings["errors"]["log"]
        timeout = 0
      else
        # On non-fatal issues, obey report settings for warnings
        level = :warn
        buttons_set = :question
        display_message = report_settings["warnings"]["show"]
        log_message = report_settings["warnings"]["log"]
        timeout = report_settings["warnings"]["timeout"]
      end

      presenter = Y2Autoinstallation::StorageProposalIssuesPresenter.new(proposal.issues_list)
      log_proposal_issues(level, presenter.to_plain) if log_message
      return true unless display_message

      dialog = Y2Autoinstallation::Dialogs::Question.new(
        presenter.to_html,
        timeout: timeout,
        buttons_set: buttons_set
      )
      dialog.run == :ok
    end


    # Log proposal issues message
    #
    # @param level   [Symbol] Message level (:error, :warn)
    # @param content [String] Text to log
    def log_proposal_issues(level, content)
      log.send(level, content)
    end

    # Preprocess partitioning settings
    #
    # @param settings [Array<Hash>, nil] Profile settings (list of drives for custom partitioning)
    def preprocessed_settings(settings)
      preprocessor = Y2Autoinstallation::PartitioningPreprocessor.new
      preprocessor.run(settings)
    end
  end

  AutoinstStorage = AutoinstStorageClass.new
  AutoinstStorage.main
end
