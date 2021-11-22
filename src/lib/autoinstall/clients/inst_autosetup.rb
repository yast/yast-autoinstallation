# Copyright (c) [2013-2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

# File:    clients/inst_autosetup.ycp
# Package: Auto-installation
# Summary: Setup and prepare system for auto-installation
# Authors: Anas Nashif <nashif@suse.de>
#          Uwe Gansert <ug@suse.de>
#
# $Id$

require "yast"
require "autoinstall/autosetup_helpers"
require "autoinstall/importer"

Yast.import "Pkg"
Yast.import "UI"
Yast.import "AutoinstConfig"
Yast.import "AutoInstall"
Yast.import "Installation"
Yast.import "Profile"
Yast.import "Progress"
Yast.import "Report"
Yast.import "AutoinstStorage"
Yast.import "AutoinstScripts"
Yast.import "AutoinstGeneral"
Yast.import "AutoinstSoftware"
Yast.import "Popup"
Yast.import "Arch"
Yast.import "Call"
Yast.import "ProductControl"
Yast.import "ServicesManager"
Yast.import "AutoinstFunctions"
Yast.import "Wizard"

module Y2Autoinstallation
  module Clients
    class InstAutosetup < Yast::Client
      include Yast::Logger
      include Y2Autoinstallation::AutosetupHelpers

      Target = AutoinstConfigClass::Target

      def main
        textdomain "autoinst"

        @help_text = _(
          "<P>Please wait while the system is prepared for autoinstallation.</P>"
        )
        @progress_stages = [
          _("Configure General Settings "),
          _("Set up language"),
          _("Create partition plans"),
          _("Configure Bootloader"),
          _("Configure security settings"),
          _("Set up configuration management system"),
          _("Registration"),
          _("Configure Kdump"),
          _("Configure Software selections"),
          _("Configure Systemd Default Target"),
          _("Configure users and groups"),
          _("Import SSH keys/settings"),
          _("Set up user defined configuration files"),
          _("Confirm License"),
          _("Configure firewall")
        ]

        @progress_descriptions = [
          _("Configuring general settings..."),
          _("Setting up language..."),
          _("Creating partition plans..."),
          _("Configuring Bootloader..."),
          _("Configuring security settings"),
          _("Setting up configuration management system..."),
          _("Registering the system..."),
          _("Configuring Kdump..."),
          _("Configuring Software selections..."),
          _("Configuring Systemd Default Target..."),
          _("Importing users and groups configuration..."),
          _("Importing SSH keys/settings..."),
          _("Setting up user defined configuration files..."),
          _("Confirming License..."),
          _("Configuring the firewall")
        ]

        Progress.New(
          _("Preparing System for Automated Installation"),
          "", # progress_title
          Builtins.size(@progress_stages), # progress bar length
          @progress_stages,
          @progress_descriptions,
          @help_text
        )

        return :abort if UI.PollInput == :abort && Popup.ConfirmAbort(:painless)

        #
        # Set workflow variables
        #
        Progress.NextStage

        # Ensure that we clean product cache to avoid product from control (bsc#1156058)
        AutoinstFunctions.reset_product
        # Merging selected product
        AutoinstSoftware.merge_product(AutoinstFunctions.selected_product)

        # configure general settings
        general_section = Profile.current.fetch_as_hash("general")
        networking_section = Profile.current.fetch_as_hash("networking")
        pkg_list = networking_section["managed"] ? ["NetworkManager"] : []
        AutoinstGeneral.Import(general_section)
        log.info("general: #{general_section}")
        AutoinstGeneral.Write

        autosetup_network

        if Builtins.haskey(Profile.current, "add-on")
          Progress.Title(_("Handling Add-On Products..."))
          unless Call.Function(
            "add-on_auto",
            ["Import", Ops.get_map(Profile.current, "add-on", {})]
          )

            log.warn("User has aborted the installation.")
            return :abort
          end
          Profile.remove_sections("add-on")

          Call.Function("add-on_auto", ["Write"])

          # Recover partitioning settings that were removed by the add-on_auto client (bsc#1073548)
          Yast::AutoinstStorage.import_general_settings(general_section["storage"])

          # The entry "kexec_reboot" in the Product description can be set
          # by the AutoYaST configuration setting (general/forceboot) and should
          # not be reset by any other Product description file.
          # So we set it here again.
          # bnc#981434
          AutoinstGeneral.SetRebootAfterFirstStage
        end

        #
        # Set it in the Language module.
        #
        Progress.NextStage
        Progress.Title(_("Configuring language..."))

        autosetup_country

        # one can override the <confirm> option by the commandline parameter y2confirm
        @tmp = Convert.to_string(
          SCR.Read(path(".target.string"), "/proc/cmdline")
        )
        if !@tmp.nil? &&
            Builtins.contains(Builtins.splitstring(@tmp, " \n"), "y2confirm")
          AutoinstConfig.Confirm = true
          Builtins.y2milestone("y2confirm found and confirm turned on")
        end

        return :abort if UI.PollInput == :abort && Popup.ConfirmAbort(:painless)

        # moved here from autoinit for fate #301193
        # needs testing
        if Arch.s390
          if Builtins.haskey(Profile.current, "dasd")
            Builtins.y2milestone("dasd found")
            if Call.Function("dasd_auto", ["Import", Ops.get_map(Profile.current, "dasd", {})])
              Call.Function("dasd_auto", ["Write"])
            end
          end
          if Builtins.haskey(Profile.current, "zfcp")
            Builtins.y2milestone("zfcp found")
            if Call.Function("zfcp_auto", ["Import", Ops.get_map(Profile.current, "zfcp", {})])
              Call.Function("zfcp_auto", ["Write"])
            end
          end
        end

        #
        # Partitioning and Storage
        # //////////////////////////////////////////////////////////////////////

        Progress.NextStage

        # Pre-scripts can modify the AutoYaST profile. Even more, a pre-script could change
        # the initial disks layout/configuration (e.g., by creating a new partition).
        # It is difficult to evaluate whether a pre-script has modified something related
        # to storage devices, so a re-probing is always performed here (related to bsc#1133045).
        probe_storage

        write_storage = if Profile.current["partitioning_advanced"] &&
            !Profile.current["partitioning_advanced"].empty?
          AutoinstStorage.ImportAdvanced(Profile.current["partitioning_advanced"])
        else
          AutoinstStorage.Import(Profile.current["partitioning"])
        end

        return :abort unless write_storage

        semiauto_partitions = general_section["semi-automatic"]&.include?("partitioning")

        if semiauto_partitions
          Builtins.y2milestone("Partitioning manual setup")
          # Yes, do not set Storage testsuite here as we want really GUI with proposal
          Call.Function("inst_disk_proposal", ["enable_next" => true])
          write_storage = true
        end

        if write_storage &&
            !AutoinstStorage.Write
          Report.Error(_("Error while configuring partitions.\nTry again.\n"))
          Builtins.y2error("Aborting...")
          return :abort
        end

        # Bootloader
        # The bootloader has to be called before software selection.
        # So the software selection is aware and can manage packages
        # needed by the bootloader (bnc#876161)

        return :abort if UI.PollInput == :abort && Popup.ConfirmAbort(:painless)

        Progress.NextStage

        return :abort unless WFM.CallFunction(
          "bootloader_auto",
          ["Import", Profile.current.fetch_as_hash("bootloader")]
        )

        Progress.NextStage

        # Importing security settings
        autosetup_security
        return :abort if UI.PollInput == :abort && Popup.ConfirmAbort(:painless)

        Progress.NextStage

        # The configuration_management has to be called before software selection.
        # So the software selection is aware and can manage packages
        # needed by the configuration_management.
        if Profile.current["configuration_management"]
          return :abort unless WFM.CallFunction(
            "configuration_management_auto",
            ["Import", Profile.current["configuration_management"]]
          )

          # Do not start it in second installation stage again.
          # Provisioning will already be called in the first stage.
          Profile.remove_sections("configuration_management")
        end

        return :abort if UI.PollInput == :abort && Popup.ConfirmAbort(:painless)

        Progress.NextStage

        # Register system
        return :abort unless suse_register

        Progress.NextStage

        # SLES only. Have to be run before software to add required packages to enable kdump
        if Builtins.haskey(Profile.current, "kdump")
          Call.Function(
            "kdump_auto",
            ["Import", Ops.get_map(Profile.current, "kdump", {})]
          )
          # Don't run it again in 2nd installation stage
          Profile.remove_sections("kdump")
        end

        # Software

        return :abort if UI.PollInput == :abort && Popup.ConfirmAbort(:painless)

        Progress.NextStage

        # Evaluating package and patterns selection.
        # Selection will be stored in PackageAI.
        AutoinstSoftware.Import(Ops.get_map(Profile.current, "software", {}))

        # Add additional packages in order to run YAST modules which
        # have been defined in the AutoYaST configuration file.
        # Selection will be stored in PackageAI.
        add_yast2_dependencies if AutoinstFunctions.second_stage_required?
        # Also add packages needed by some profile configuration but missing the
        # explicit declaration in the software section
        AutoinstSoftware.add_additional_packages(pkg_list) unless pkg_list.empty?

        # Adding selections (defined in PackageAI) to libzypp and solving
        # package dependencies.
        if !AutoinstSoftware.Write
          Report.Error(
            _("Error while configuring software selections.\nTry again.\n")
          )
          Builtins.y2error("Aborting...")
          return :abort
        end
        # fate #301321 - AutoYaST imaging support
        # no generic images, just the ones the manual installation would use too, to speed up
        # installation
        #
        # no check if section is available makes product default possible
        Call.Function(
          "deploy_image_auto",
          ["Import", Ops.get_map(Profile.current, "deploy_image", {})]
        )
        Call.Function("deploy_image_auto", ["Write"])

        Progress.NextStage

        if Profile.current.key?("runlevel")
          # still supporting old format "runlevel"
          ServicesManager.import(Profile.current["runlevel"])
          # Do not start it in second installation stage again.
          # Writing will be called in inst_finish.
          Profile.remove_sections("runlevel")
        elsif Profile.current.key? "services-manager"
          ServicesManager.import(Profile.current["services-manager"])
          # Do not start it in second installation stage again.
          # Writing will be called in inst_finish.
          Profile.remove_sections("services-manager")
        else
          # We will have to set default entries which are defined
          # in the import call of ServicesManager
          ServicesManager.import({})
        end

        #
        # Import users configuration from the profile
        #
        Progress.NextStage
        return :abort unless autosetup_users

        #
        # Import profile settings for copying SSH keys from a
        # previous installation
        #
        Progress.NextStage
        if Profile.current["ssh_import"]
          config = Profile.current["ssh_import"]
          Profile.remove_sections("ssh_import")
          return :abort unless WFM.CallFunction(
            "ssh_import_auto",
            ["Import", config]
          )
        end

        #
        # Import profile settings for creating configuration files.
        #
        Progress.NextStage
        return :abort unless autosetup_files

        #
        # Checking Base Product licenses
        #
        Progress.NextStage
        if general_section.fetch_as_hash("mode").fetch("confirm_base_product_license", false)
          result = nil
          while result != :next
            result = WFM.CallFunction("inst_product_license", [{ "enable_back"=>false }])
            return :abort if result == :abort && Yast::Popup.ConfirmAbort(:painless)
          end
        end

        Progress.NextStage
        #
        # Run firewall configuration according to the profile
        #
        autosetup_firewall

        # Results of imported values semantic check.
        return :abort unless AutoInstall.valid_imported_values

        Progress.Finish

        @ret = ProductControl.RunFrom(ProductControl.CurrentStep + 1, true)

        return :finish if @ret == :next

        @ret
      end

      # Import Files section from profile
      #
      # @return [Boolean] Determine whether the import was successful
      def autosetup_files
        result = importer.import_entry("files")
        result.sections.each { |e| Profile.remove_sections(e) }
        result.success?
      end

      # Import Users configuration from profile
      #
      # @return [Boolean] Determine whether the import was successful
      def autosetup_users
        result = importer.import_entry("users")
        result.sections.each { |e| Profile.remove_sections(e) }
        result.success?
      end

      # Import security settings from profile
      #
      # @return [Boolean] Determine whether the import was successful
      def autosetup_security
        result = importer.import_entry("security")
        result.sections.each { |e| Profile.remove_sections(e) }
        result.success?
      end

      # Add YaST2 packages dependencies
      def add_yast2_dependencies
        AutoinstSoftware.AddYdepsFromProfile(Profile.current.keys)
      end

      def importer
        @importer ||= Y2Autoinstallation::Importer.new(Profile.current)
      end
    end
  end
end
