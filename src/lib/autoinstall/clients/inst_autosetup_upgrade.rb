require "autoinstall/autosetup_helpers"

require "y2packager/product_upgrade"
require "yast2/popup"

Yast.import "AddOnProduct"
Yast.import "Arch"
Yast.import "AutoInstall"
Yast.import "AutoinstConfig"
Yast.import "AutoinstGeneral"
Yast.import "AutoinstScripts"
Yast.import "AutoinstSoftware"
Yast.import "AutoinstStorage"
Yast.import "Call"
Yast.import "Console"
Yast.import "Installation"
Yast.import "Keyboard"
Yast.import "Language"
Yast.import "PackageCallbacks"
Yast.import "Packages"
Yast.import "Pkg"
Yast.import "Popup"
Yast.import "Product"
Yast.import "ProductControl"
Yast.import "ProductFeatures"
Yast.import "Profile"
Yast.import "Progress"
Yast.import "Report"
Yast.import "RootPart"
Yast.import "Timezone"
Yast.import "UI"
Yast.import "Update"

module Y2Autoinstallation
  module Clients
    class InstAutosetupUpgrade
      include Yast
      include Yast::Logger
      include Yast::I18n
      include Y2Autoinstallation::AutosetupHelpers

      def main
        textdomain "autoinst"

        Yast.include self, "autoinstall/ask.rb"

        Progress.New(
          _("Preparing System for Automated Installation"),
          "", # progress_title
          progress_stages.size, # progress bar length
          progress_stages,
          progress_descriptions,
          help_text
        )

        return :abort if UI.PollInput == :abort && Popup.ConfirmAbort(:painless)

        Progress.NextStage

        # configure general settings

        #
        # Set workflow variables
        #
        general_section = Profile.current["general"] || {}
        AutoinstGeneral.Import(general_section)
        Builtins.y2milestone(
          "general: %1",
          general_section
        )
        AutoinstGeneral.Write

        if Builtins.haskey(Profile.current, "add-on")
          unless Call.Function(
            "add-on_auto",
            ["Import", Ops.get_map(Profile.current, "add-on", {})]
          )

            log.warn("User has aborted the installation.")
            return :abort
          end
          Call.Function("add-on_auto", ["Write"])

          # Recover partitioning settings that were removed by the add-on_auto client (bsc#1073548)
          Yast::AutoinstStorage.import_general_settings(general_section["storage"])
        end

        @use_utf8 = true # utf8 is default

        @displayinfo = UI.GetDisplayInfo
        if !Ops.get_boolean(@displayinfo, "HasFullUtf8Support", true)
          @use_utf8 = false # fallback to ascii
        end

        #
        # Set it in the Language module.
        #
        Progress.NextStep
        Progress.Title(_("Configuring language..."))
        Language.Import(Ops.get_map(Profile.current, "language", {}))

        #
        # Set Console font
        #
        Installation.encoding = Console.SelectFont(Language.language)

        Installation.encoding = "UTF-8" if Ops.get_boolean(@displayinfo, "HasFullUtf8Support", true)

        unless Language.SwitchToEnglishIfNeeded(true)
          UI.SetLanguage(Language.language, Installation.encoding)
          WFM.SetLanguage(Language.language, "UTF-8")
        end

        if Builtins.haskey(Profile.current, "timezone")
          Timezone.Import(Ops.get_map(Profile.current, "timezone", {}))
        end
        # bnc#891808: infer keyboard from language if needed
        if Profile.current.key?("keyboard")
          Keyboard.Import(Profile.current["keyboard"] || {}, :keyboard)
        elsif Profile.current.key?("language")
          Keyboard.Import(Profile.current["language"] || {}, :language)
        end

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
        if Arch.s390 && AutoinstConfig.remoteProfile == true
          Builtins.y2milestone("arch=s390 and remote_profile=true")
          if Builtins.haskey(Profile.current, "dasd")
            Builtins.y2milestone("dasd found")
            if Call.Function("dasd_auto", ["Import", Ops.get_map(Profile.current, "dasd", {})])
              # Activate imported disk bnc#883747
              Call.Function("dasd_auto", ["Write"])
            end
          end
          if Builtins.haskey(Profile.current, "zfcp")
            Builtins.y2milestone("zfcp found")
            if Call.Function("zfcp_auto", ["Import", Ops.get_map(Profile.current, "zfcp", {})])
              # Activate imported disk bnc#883747
              Call.Function("zfcp_auto", ["Write"])
            end
          end
        end

        Progress.NextStage

        if !(Mode.autoupgrade && AutoinstConfig.ProfileInRootPart)
          # reread only if target system is not yet initialized (bnc#673033)
          probe_storage

          return :abort if :abort == WFM.CallFunction("inst_update_partition_auto", [])
        end

        # Registration

        return :abort if UI.PollInput == :abort && Popup.ConfirmAbort(:painless)

        Progress.NextStage
        return :abort unless suse_register

        software_upgrade

        return :abort if UI.PollInput == :abort && Popup.ConfirmAbort(:painless)

        Progress.NextStage

        # Bootloader
        # FIXME: De-duplicate with inst_autosetup
        # Bootloader import / proposal is necessary to match changes done for manual
        # upgrade, when new configuration is created instead of reusing old one, which
        # cannot be converted from other bootloader configuration to GRUB2 format.
        # Without this code, YaST sticks with previously installed bootloader even if
        # it is not included in the new distro
        #
        # This fix was tested with AutoYaST profile as atached to bnc#885634 (*), as well as
        # its alternative without specifying bootloader settings, in VirtualBox with
        # single disk, updating patched SLES11-SP3 to SLES12 Beta10
        # https://bugzilla.novell.com/show_bug.cgi?id=885634#c3

        return :abort if UI.PollInput == :abort && Popup.ConfirmAbort(:painless)

        Progress.NextStage

        return :abort unless WFM.CallFunction(
          "bootloader_auto",
          ["Import", Ops.get_map(Profile.current, "bootloader", {})]
        )

        # SLES only, the only way to have kdump configured immediately after upgrade
        if Builtins.haskey(Profile.current, "kdump")
          Call.Function(
            "kdump_auto",
            ["Import", Ops.get_map(Profile.current, "kdump", {})]
          )
        end

        # Backup
        Builtins.y2internal("Backup: %1", Ops.get(Profile.current, "backup"))
        Installation.update_backup_modified = Ops.get_boolean(
          Profile.current,
          ["backup", "modified"],
          true
        )
        Builtins.y2internal(
          "Backup modified: %1",
          Installation.update_backup_modified
        )
        Installation.update_backup_sysconfig = Ops.get_boolean(
          Profile.current,
          ["backup", "sysconfig"],
          true
        )
        Installation.update_remove_old_backups = Ops.get_boolean(
          Profile.current,
          ["backup", "remove_old"],
          false
        )

        #
        # Checking if at least one base product has been selected/evaluated.
        #
        begin
          Product.FindBaseProducts
        rescue StandardError
          msg = _("No new base product has been set.\n" \
           "Please check the <b>software</b>/<b>products</b> entry in the " \
           "AutoYaST configuration file.<br><br>" \
           "Following base products are available:<br>")
          Yast::AutoinstFunctions.available_base_products_hash.each do |product|
            msg += "#{product[:name]} (#{product[:summary]})<br>"
          end
          Yast2::Popup.show(msg, richtext: true) # No timeout because we are stopping the upgrade.
          return :abort
        end

        #
        # Checking Base Product licenses
        #
        Progress.NextStage
        if general_section["mode"]&.fetch("confirm_base_product_license", false)
          result = nil
          while result != :next
            result = WFM.CallFunction("inst_product_license", [{ "enable_back"=>false }])
            return :abort if result == :abort && Yast::Popup.ConfirmAbort(:painless)
          end
        end

        # Results of imported values semantic check.
        return :abort unless AutoInstall.valid_imported_values

        Progress.Finish

        @ret = ProductControl.RunFrom(
          Ops.add(ProductControl.CurrentStep, 1),
          true
        )
        return :finish if @ret == :next

        @ret
      end

    private

      def help_text
        _(
          "<P>Please wait while the system is prepared for autoinstallation.</P>"
        )
      end

      def progress_stages
        [
          _("Configure General Settings "),
          _("Set up language"),
          _("Registration"),
          _("Configure Software selections"),
          _("Configure Bootloader"),
          _("Confirm License")
        ]
      end

      def progress_descriptions
        [
          _("Configuring general settings..."),
          _("Setting up language..."),
          _("Registering the system..."),
          _("Configuring Software selections..."),
          _("Configuring Bootloader..."),
          _("Confirming License...")
        ]
      end

      def software_upgrade
        # initialize package manager
        Packages.Init(true)

        # initialize target
        PackageCallbacks.SetConvertDBCallbacks

        Pkg.TargetInit(Installation.destdir, false)

        # read old and new product
        Update.GetProductName

        # FATE #301990, Bugzilla #238488
        # Set initial update-related (packages/patches) values from control file
        Update.InitUpdate

        # FATE #301844
        Builtins.y2milestone(
          "Previous '%1', New '%2' RootPart",
          RootPart.previousRootPartition,
          RootPart.selectedRootPartition
        )
        if RootPart.previousRootPartition != RootPart.selectedRootPartition
          RootPart.previousRootPartition = RootPart.selectedRootPartition

          # check whether update is possible
          # reset settings in respect to the selected system
          Update.Reset
          Builtins.y2milestone("Upgrade is not supported") if !Update.IsProductSupportedForUpgrade
        end

        return if Update.did_init1

        # connect target with package manager
        Update.did_init1 = true

        # bnc #300540
        # bnc #391785
        Update.DropObsoletePackages

        # make sure the packages needed for accessing the installation repository
        # are installed, e.g. "cifs-mount" for SMB or "nfs-client" for NFS repositories
        Packages.sourceAccessPackages.each do |package|
          Pkg::ResolvableInstall(package, :package)
        end

        # bnc #382208

        # bnc#582702 - do not select kernel on update, leave that on dependencies like
        # 'zypper dup' therefore commented line below out
        #          Packages::SelectKernelPackages ();

        # FATE #301990, Bugzilla #238488
        # Control the upgrade process better
        # param is now obsolete https://github.com/yast/yast-pkg-bindings/commit/714aef89f9d8e9b188f278ae3ee0981b998a9b33#diff-1b3650bcdce18023a6b6d681d00996e6R1550
        Pkg.PkgUpdateAll({})

        # select add-ons replacement at first, so later it can be explicitelly removed by user
        # profile or by obsolete upgrades
        AddOnProduct.missing_upgrades.each { |p| Pkg.ResolvableInstall(p, :product) }
        # deselect the upgraded obsolete products (bsc#1133215)
        Y2Packager::ProductUpgrade.remove_obsolete_upgrades

        sys_patterns = Packages.ComputeSystemPatternList
        Builtins.foreach(sys_patterns) do |pat|
          Pkg.ResolvableInstall(pat, :pattern)
        end
        # this is new, (de)select stuff from the profile
        packages = Profile.current["software"]&.public_send(:[], "packages") || []
        patterns = Profile.current["software"]&.public_send(:[], "patterns") || []
        products = Profile.current["software"]&.public_send(:[], "products") || []
        remove_packages = Profile.current["software"]&.public_send(:[], "remove-packages") || []
        remove_patterns = Profile.current["software"]&.public_send(:[], "remove-patterns") || []
        remove_products = Profile.current["software"]&.public_send(:[], "remove-products") || []
        # neutralize first, otherwise the change may have no effect
        remove_patterns.each { |p| Pkg.ResolvableNeutral(p, :pattern, true) }
        remove_packages.each { |p| Pkg.ResolvableNeutral(p, :package, true) }
        remove_products.each { |p| Pkg.ResolvableNeutral(p, :product, true) }
        patterns.each { |p| Pkg.ResolvableNeutral(p, :pattern, true) }
        packages.each { |p| Pkg.ResolvableNeutral(p, :package, true) }
        products.each { |p| Pkg.ResolvableNeutral(p, :product, true) }
        # now set the final status
        remove_patterns.each { |p| Pkg.ResolvableRemove(p, :pattern) }
        remove_packages.each { |p| Pkg.ResolvableRemove(p, :package) }
        remove_products.each { |p| Pkg.ResolvableRemove(p, :product) }
        patterns.each { |p| Pkg.ResolvableInstall(p, :pattern) }
        packages.each { |p| Pkg.ResolvableInstall(p, :package) }
        products.each { |p| Pkg.ResolvableInstall(p, :product) }

        # old stuff again here
        if Pkg.PkgSolve(false)
          Update.solve_errors = 0
        else
          Update.solve_errors = Pkg.PkgSolveErrors
          stop = Profile.current["upgrade"].public_send(:[], "stop_on_solver_conflict")
          # default behavior is to stop, so nil is as true
          AutoinstConfig.Confirm = true if stop || stop.nil?
        end
      end
    end
  end
end
