# File:  modules/AutoinstSoftware.ycp
# Package:  Autoyast
# Summary:  Software
# Authors:  Anas Nashif <nashif@suse.de>
#
# $Id$
#
require "yast"
require "y2storage"
require "y2packager/product"
require "y2packager/resolvable"
require "autoinstall/package_searcher"
require "autoinstall/entries/registry"

module Yast
  class AutoinstSoftwareClass < Module
    include Yast::Logger

    # This file is created by pkg-bindings when the package solver fails,
    # it contains some details of the failure
    BAD_LIST_FILE = "/var/log/YaST2/badlist".freeze

    # Maximal amount of packages which will be shown
    # in a popup.
    MAX_PACKAGE_VIEW = 5

    def main
      Yast.import "UI"
      Yast.import "Pkg"
      textdomain "autoinst"

      Yast.import "Profile"
      Yast.import "Summary"
      Yast.import "Stage"
      Yast.import "SpaceCalculation"
      Yast.import "Packages"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "Kernel"
      Yast.import "AutoinstConfig"
      Yast.import "AutoinstFunctions"
      Yast.import "ProductControl"
      Yast.import "Mode"
      Yast.import "Misc"
      Yast.import "Directory"
      Yast.import "PackageSystem"
      Yast.import "ProductFeatures"
      Yast.import "WorkflowManager"
      Yast.import "Product"

      Yast.include self, "autoinstall/io.rb"

      # All shared data are in yast2.rpm to break cyclic dependencies
      Yast.import "AutoinstData"
      Yast.import "PackageAI"

      @Software = {}

      # patterns
      @patterns = []

      # Kernel, force type of kernel to be installed
      @kernel = ""

      # default value of settings modified
      @modified = false

      @inst = []
      @all_xpatterns = []
      @packagesAvailable = []
      @patternsAvailable = []

      @instsource = ""
      AutoinstSoftware()
    end

    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      @modified = true

      nil
    end

    # Functions which returns if the settings were modified
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end

    # Import data
    # @param [Hash] settings settings to be imported
    # @return true on success
    def Import(settings)
      settings = deep_copy(settings)
      @Software = deep_copy(settings)
      @patterns = settings.fetch("patterns", [])
      @instsource = settings.fetch("instsource", "")

      @packagesAvailable = Pkg.GetPackages(:available, true)
      @patternsAvailable = Y2Packager::Resolvable.find(
        kind:         :pattern,
        user_visible: true
      ).map(&:name)

      regexFound = []
      Ops.set(
        settings,
        "packages",
        Builtins.filter(Ops.get_list(settings, "packages", [])) do |want_pack|
          next true if !Builtins.issubstring(want_pack, "/")

          want_pack = Builtins.deletechars(want_pack, "/")
          Builtins.foreach(@packagesAvailable) do |pack|
            Builtins.y2milestone("matching %1 against %2", pack, want_pack)
            if Builtins.regexpmatch(pack, want_pack)
              regexFound = Builtins.add(regexFound, pack)
              Builtins.y2milestone("match")
            end
          end
          false
        end
      )
      Ops.set(
        settings,
        "packages",
        Convert.convert(
          Builtins.union(Ops.get_list(settings, "packages", []), regexFound),
          from: "list",
          to:   "list <string>"
        )
      )

      regexFound = []
      @patterns = Builtins.filter(@patterns) do |want_patt|
        next true if !Builtins.issubstring(want_patt, "/")

        want_patt = Builtins.deletechars(want_patt, "/")
        Builtins.foreach(patternsAvailable) do |patt|
          Builtins.y2milestone("matching %1 against %2", patt, want_patt)
          if Builtins.regexpmatch(patt, want_patt)
            regexFound = Builtins.add(regexFound, patt)
            Builtins.y2milestone("match")
          end
        end
        false
      end
      @patterns = Convert.convert(
        Builtins.union(@patterns, regexFound),
        from: "list",
        to:   "list <string>"
      )

      PackageAI.toinstall = settings.fetch("packages", [])
      @kernel = settings.fetch("kernel", "")

      addPostPackages(settings.fetch("post-packages", []))
      AutoinstData.post_patterns = settings.fetch("post-patterns", [])
      PackageAI.toremove = settings.fetch("remove-packages", [])

      true
    end

    def AddYdepsFromProfile(entries)
      Builtins.y2milestone("AddYdepsFromProfile entries %1", entries)
      pkglist = []
      # Evaluating packages via RPM supplements ( e.g. autoyast(kdump) )
      req_packages = Y2Autoinstallation::PackagerSearcher.new(entries).evaluate_via_rpm
      entries.reject! do |e|
        packs = req_packages[e]
        if packs.empty?
          false
        else
          log.info "AddYdepsFromProfile add packages #{packs} for entry #{e}"
          pkglist += packs
          true
        end
      end

      # Evaluating packages for not founded entries via desktop file and rnc files.
      entries.each do |e|
        registry = Y2Autoinstallation::Entries::Registry.instance
        description = registry.descriptions.find { |d| d.managed_keys.include?(e) }
        # if needed taking default because no entry has been defined in the *.desktop file
        yast_module = description ? description.module_name : e
        # FIXME: Does not work see below
        #
        # This does currently not work at all as the packages provide this
        # with the module name camel-cased; e.g.:
        #
        #   application(YaST2/org.opensuse.yast.Kdump.desktop)
        #
        # As there's no way to predict which letters are upper-cased this cannot work at all.
        #
        # The fallback method via #required_packages relies on a
        # pre-calculated data set which may or may not reflect the
        # dependencies of the packages in the repo.
        #
        # This area should be re-thought entirely.
        #
        provide = "application(YaST2/org.opensuse.yast.#{yast_module}.desktop)"

        packages = Pkg.PkgQueryProvides(provide)
        if packages.empty?
          packs = Y2Autoinstallation::PackagerSearcher.new([e]).evaluate_via_schema[e]
          if packs.nil? || packs.empty?
            log.info "No package provides: #{provide}"
          else
            log.info "AddYdepsFromProfile add packages #{packs} for entry #{e}"
            pkglist += packs
          end
        else
          name = packages[0][0]
          log.info "AddYdepsFromProfile add package #{name} for entry #{e}"
          pkglist.push(name) if !pkglist.include?(name)
        end
      end
      pkglist.uniq!
      Builtins.y2milestone("AddYdepsFromProfile pkglist %1", pkglist)
      pkglist.each do |p|
        if !PackageAI.toinstall.include?(p) && @packagesAvailable.include?(p)
          PackageAI.toinstall.push(p)
        end
      end
    end

    # Constructer
    def AutoinstSoftware
      if Stage.cont && Mode.autoinst
        Pkg.TargetInit("/", false)
        Import(Ops.get_map(Profile.current, "software", {}))
      end
      nil
    end

    # Export data
    # @return dumped settings (later acceptable by Import())
    def Export
      s = {}
      s["kernel"] = @kernel if !@kernel.empty?
      s["patterns"] = @patterns if !@patterns.empty?

      pkg_toinstall = PackageAI.toinstall
      s["packages"] = pkg_toinstall if !pkg_toinstall.empty?

      pkg_post = AutoinstData.post_packages
      s["post-packages"] = pkg_post if !pkg_post.empty?

      pkg_toremove = PackageAI.toremove
      s["remove-packages"] = PackageAI.toremove if !pkg_toremove.empty?

      s["instsource"] = @instsource

      # In the installed system the flag solver.onlyRequires in zypp.conf is
      # set to true. This differs from the installation process. So we have
      # to set "install_recommended" to true in order to reflect the
      # installation process and cannot use the package bindings. (bnc#990494)
      # OR: Each product (e.g. CASP) can set it in the control.xml file.
      rec = ProductFeatures.GetStringFeature(
        "software",
        "clone_install_recommended_default"
      )
      s["install_recommended"] = rec != "no"

      products = Product.FindBaseProducts
      raise "Found multiple base products" if products.size > 1

      s["products"] = products.map { |x| x["name"] }

      s
    end

    # Add packages needed by modules, i.e. NIS, NFS etc.
    # @param module_packages [Array<String>] list of strings packages to add
    def AddModulePackages(module_packages)
      module_packages = deep_copy(module_packages)
      PackageAI.toinstall = Builtins.toset(
        Convert.convert(
          Builtins.union(PackageAI.toinstall, module_packages),
          from: "list",
          to:   "list <string>"
        )
      )
      #
      # Update profile
      #
      Ops.set(Profile.current, "software", Export())
      nil
    end

    # Remove packages not needed by modules, i.e. NIS, NFS etc.
    # @param module_packages [Array<String>] list of strings packages to add
    def RemoveModulePackages(module_packages)
      module_packages = deep_copy(module_packages)
      PackageAI.toinstall = Builtins.filter(PackageAI.toinstall) do |p|
        !Builtins.contains(module_packages, p)
      end
      Ops.set(Profile.current, "software", Export())
      nil
    end

    # Summary
    # @return Html formatted configuration summary
    def Summary
      summary = ""

      summary = Summary.AddHeader(summary, _("Selected Patterns"))
      if Ops.greater_than(Builtins.size(@patterns), 0)
        summary = Summary.OpenList(summary)
        Builtins.foreach(@patterns) do |a|
          summary = Summary.AddListItem(summary, a)
        end
        summary = Summary.CloseList(summary)
      else
        summary = Summary.AddLine(summary, Summary.NotConfigured)
      end
      summary = Summary.AddHeader(summary, _("Individually Selected Packages"))
      summary = Summary.AddLine(
        summary,
        Builtins.sformat("%1", Builtins.size(PackageAI.toinstall))
      )

      summary = Summary.AddHeader(summary, _("Packages to Remove"))
      summary = Summary.AddLine(
        summary,
        Builtins.sformat("%1", Builtins.size(PackageAI.toremove))
      )

      if @kernel != ""
        summary = Summary.AddHeader(summary, _("Force Kernel Package"))
        summary = Summary.AddLine(summary, Builtins.sformat("%1", @kernel))
      end
      summary
    end

    # Compute list of packages selected by user and other packages needed for important
    # configuration modules.
    # @return [Array] of strings list of packages needed for autoinstallation
    def autoinstPackages
      allpackages = []

      # the primary list of packages
      allpackages = Convert.convert(
        Builtins.union(allpackages, PackageAI.toinstall),
        from: "list",
        to:   "list <string>"
      )

      # In autoinst mode, a kernel should not be  available
      # in <packages>
      if Builtins.size(@kernel) == 0
        kernel_pkgs = Kernel.ComputePackages
        allpackages = Convert.convert(
          Builtins.union(allpackages, kernel_pkgs),
          from: "list",
          to:   "list <string>"
        )
      elsif Pkg.IsAvailable(@kernel)
        allpackages = Builtins.add(allpackages, @kernel)
        kernel_nongpl = Ops.add(@kernel, "-nongpl")

        allpackages = Builtins.add(allpackages, kernel_nongpl) if Pkg.IsAvailable(kernel_nongpl)
      else
        Builtins.y2warning("%1 not available, using kernel-default", @kernel)
        kernel_pkgs = Kernel.ComputePackages
        allpackages = Convert.convert(
          Builtins.union(allpackages, kernel_pkgs),
          from: "list",
          to:   "list <string>"
        )
      end

      deep_copy(allpackages)
    end

    # Configure software settings
    #
    # @return [Boolean]
    def Write
      ok = true

      Packages.Init(true)
      selected_base_products = Product.FindBaseProducts.map { |p| p["name"] }
      # Resetting package selection of previous runs. This is needed
      # because it could be that additional repositories
      # are available meanwhile. (bnc#979691)
      Pkg.PkgApplReset

      # Select base product again which has been reset by the previous call.
      # (bsc#1143106)
      selected_base_products.each { |name| Pkg.ResolvableInstall(name, :product) }

      sw_settings = Profile.current.fetch("software", {})
      Pkg.SetSolverFlags(
        "ignoreAlreadyRecommended" => Mode.normal,
        "onlyRequires"             => !sw_settings.fetch("install_recommended", true)
      )

      failed = []

      # Add storage-related software packages (filesystem tools etc.) to the
      # set of packages to be installed.
      storage_features = Y2Storage::StorageManager.instance.staging.used_features
      pkg_handler = Y2Storage::PackageHandler.new(storage_features.pkg_list)
      pkg_handler.set_proposal_packages

      # switch for recommended patterns installation (workaround for our very weird pattern design)
      if sw_settings.fetch("install_recommended", false) == false
        # set SoftLock to avoid the installation of recommended patterns (#159466)
        Y2Packager::Resolvable.find(kind: :pattern).each do |p|
          Pkg.ResolvableSetSoftLock(p.name, :pattern)
        end
      end

      Builtins.foreach(Builtins.toset(@patterns)) do |p|
        failed = Builtins.add(failed, p) if !Pkg.ResolvableInstall(p, :pattern)
      end

      if Ops.greater_than(Builtins.size(failed), 0)
        Builtins.y2error(
          "Error while setting pattern: %1",
          Builtins.mergestring(failed, ",")
        )
        Report.Warning(
          Builtins.sformat(
            _("Could not set patterns: %1."),
            Builtins.mergestring(failed, ",")
          )
        )
      end

      selected_product = AutoinstFunctions.selected_product
      if selected_product
        log.info "Selecting product #{selected_product.inspect} for installation"
        selected_product.select
      else
        log.info "No product has been selected for installation"
      end

      SelectPackagesForInstallation()

      computed_packages = Packages.ComputeSystemPackageList
      Builtins.foreach(computed_packages) do |pack2|
        if Ops.greater_than(Builtins.size(@kernel), 0) && pack2 != @kernel &&
            Builtins.search(pack2, "kernel-") == 0
          Builtins.y2milestone("taboo for kernel %1", pack2)
          PackageAI.toremove = Builtins.add(PackageAI.toremove, pack2)
        end
      end

      #
      # Now remove all packages listed in remove-packages
      #
      Builtins.y2milestone("Packages to be removed: %1", PackageAI.toremove)
      if Ops.greater_than(Builtins.size(PackageAI.toremove), 0)
        Builtins.foreach(PackageAI.toremove) do |rp|
          # Pkg::ResolvableSetSoftLock( rp, `package ); // FIXME: maybe better Pkg::PkgTaboo(rp) ?
          Pkg.PkgTaboo(rp)
        end

        Pkg.DoRemove(PackageAI.toremove)
      end

      #
      # Solve dependencies
      #
      if !Pkg.PkgSolve(false)
        # TRANSLATORS: Error message
        msg = _("The package resolver run failed. Please check your software " \
          "section in the autoyast profile.")
        # TRANSLATORS: Error message, %s is replaced by "/var/log/YaST2/y2log"
        msg += "\n" + _("Additional details can be found in the %s file.") %
          "/var/log/YaST2/y2log"

        # read the details saved by pkg-bindings
        if File.exist?(BAD_LIST_FILE)
          msg += "\n\n"
          msg += File.read(BAD_LIST_FILE)
        end

        Report.LongError(msg)
      end

      SpaceCalculation.ShowPartitionWarning

      ok
    end

    # Initialize temporary target
    def pmInit
      #        string tmproot = AutoinstConfig::tmpDir;

      #        SCR::Execute(.target.mkdir, tmproot + "/root");
      #        Pkg::TargetInit( tmproot + "/root", true);
      #        Pkg::TargetInit( "/", true);
      Pkg.TargetInit(Convert.to_string(SCR.Read(path(".target.tmpdir"))), true)
      Builtins.y2milestone("SourceStartCache: %1", Pkg.SourceStartCache(false))
      nil
    end

    # Add post packages
    # @param calcpost [Array<String>] list calculated post packages
    def addPostPackages(calcpost)
      # filter out already installed packages
      calcpost.reject! { |p| PackageSystem.Installed(p) }

      calcpost = deep_copy(calcpost)
      AutoinstData.post_packages = Convert.convert(
        Builtins.toset(Builtins.union(calcpost, AutoinstData.post_packages)),
        from: "list",
        to:   "list <string>"
      )
      nil
    end

    # returns (hard and soft) locked packages
    # @return [Array<String>] list of package names
    def locked_packages
      # hard AND soft locks
      user_transact_packages(:taboo).concat(user_transact_packages(:available))
    end

    def install_packages
      # user selected packages which have not been already installed
      # rubocop:disable Lint/UselessAssignment
      packages = Pkg.FilterPackages(
        solver_selected = false,
        app_selected = true,
        user_selected = true,
        name_only = true
      )
      # rubocop:enable Lint/UselessAssignment

      # user selected packages which have already been installed
      installed_by_user = Pkg.GetPackages(:installed, true).select do |pkg_name|
        Pkg.PkgPropertiesAll(pkg_name).any? do |p|
          p["on_system_by_user"] && p["status"] == :installed
        end
      end

      # Filter out kernel and pattern packages
      kernel_packages = Pkg.PkgQueryProvides("kernel").collect do |package|
        package[0]
      end.compact.uniq
      pattern_packages = Pkg.PkgQueryProvides("pattern()").collect do |package|
        package[0]
      end.compact.uniq

      (packages + installed_by_user).uniq.select do |pkg_name|
        !kernel_packages.include?(pkg_name) &&
          !pattern_packages.include?(pkg_name)
      end
    end

    # Return list of software packages of calling client
    # in the installed environment
    # @return [Hash] map of installed software package
    #    "patterns" -> list<string> addon selections
    #    "packages" -> list<string> user selected packages
    #      "remove-packages" -> list<string> packages to remove
    def ReadHelper
      Pkg.TargetInit("/", false)
      Pkg.TargetLoad
      Pkg.SourceStartManager(true)
      Pkg.PkgSolve(false)

      @all_xpatterns = Y2Packager::Resolvable.find(
        { kind: :pattern, status: :installed },
        [:dependencies]
      )
      to_install_packages = install_packages
      patterns = []

      @all_xpatterns.each do |p|
        if !patterns.include?(p.name)
          patterns << (p.name.empty? ? "no name" : p.name)
        end
      end
      Pkg.TargetFinish

      tmproot = AutoinstConfig.tmpDir
      SCR.Execute(path(".target.mkdir"), ::File.join(tmproot, "rootclone"))
      Pkg.TargetInit(Ops.add(tmproot, "/rootclone"), true)
      Builtins.y2debug("SourceStartCache: %1", Pkg.SourceStartCache(false))

      Pkg.SourceStartManager(true)
      Pkg.TargetFinish

      new_p = []
      Builtins.foreach(patterns) do |tmp_pattern|
        found = @all_xpatterns.find { |p| p.name == tmp_pattern }
        log.info "xpattern #{found} for pattern #{tmp_pattern}"
        next unless found

        req = false
        # kick out hollow patterns (always fullfilled patterns)
        (found.dependencies || []).each do |d|
          next unless Ops.get_string(d, "res_kind", "") == "package" &&
            (Ops.get_string(d, "dep_kind", "") == "requires" ||
              Ops.get_string(d, "dep_kind", "") == "recommends")

          req = true
        end
        # workaround for our pattern design
        # a pattern with no requires at all is always fullfilled of course
        # you can fullfill the games pattern with no games installed at all
        new_p << tmp_pattern if req
      end
      patterns = new_p
      log.info "found patterns #{patterns}"

      {
        "patterns"        => patterns.sort,
        # Currently we do not have any information about user deleted packages in
        # the installed system.
        # In order to prevent a reinstallation we can take the locked packages at least.
        # (bnc#888296)
        "remove-packages" => locked_packages,
        "packages"        => to_install_packages
      }
    end

    # Return list of software packages, patterns which have been selected
    # by the user and have to be installed or removed.
    # The evaluation will be called while the yast installation workflow.
    # @return [Hash] map of to be installed/removed packages/patterns
    #    "patterns" -> list<string> of selected patterns
    #    "packages" -> list<string> user selected packages
    #           "remove-packages" -> list<string> packages to remove
    def read_initial_stage
      install_patterns =
        Y2Packager::Resolvable.find(kind: :pattern, user_visible: true).map do |pattern|
          # Do not take care about if the pattern has been selected by the user or the product
          # definition, cause we need a base selection here for the future
          # autoyast installation. (bnc#882886)
          pattern.name if pattern.status == :selected || pattern.status == :installed
        end

      software = {}
      software["packages"] = install_packages
      software["patterns"] = install_patterns.compact
      software["remove-packages"] = locked_packages
      Builtins.y2milestone("autoyast software selection: %1", software)
      deep_copy(software)
    end

    def Read
      Import((Stage.initial ? read_initial_stage : ReadHelper()))
    end

    def SavePackageSelection
      @saved_package_selection = Read()
    end

    def SavedPackageSelection
      @saved_package_selection
    end

    # Selects given product (see Y2Packager::Product) and merges its workflow
    def merge_product(product)
      raise ArgumentError, "Base product expected" if !product

      log.info("AutoinstSoftware::merge_product - using product: #{product.name}")
      product.select

      WorkflowManager.merge_product_workflow(product)

      # Adding needed autoyast packages if a second stage is needed.
      # Could have been changed due merging a products
      log.info("Checking new second stage requirement.")
      Profile.softwareCompat
    end

    def SelectPackagesForInstallation
      log.info "Individual Packages for installation: #{autoinstPackages}"
      failed_packages = {}
      failed_packages = Pkg.DoProvide(autoinstPackages) unless autoinstPackages.empty?
      computed_packages = Packages.ComputeSystemPackageList
      log.info "Computed packages for installation: #{computed_packages}"
      if !computed_packages.empty?
        failed_packages = failed_packages.merge(Pkg.DoProvide(computed_packages))
      end

      # Blaming only packages which have been selected by the AutoYaST configuration file
      log.error "Cannot select following packages for installation:" unless failed_packages.empty?
      failed_packages.reject! do |name, reason|
        if @Software["packages"]&.include?(name)
          log.error("  #{name} : #{reason} (selected by AutoYaST configuration file)")
          false
        else
          log.error("  #{name} : #{reason} (selected by YAST automatically)")
          true
        end
      end

      unless failed_packages.empty?
        not_selected = ""
        suggest_y2log = false
        failed_count = failed_packages.size
        if failed_packages.size > MAX_PACKAGE_VIEW
          failed_packages = failed_packages.first(MAX_PACKAGE_VIEW).to_h
          suggest_y2log = true
        end
        failed_packages.each do |name, reason|
          not_selected << "#{name}: #{reason}\n"
        end
        # TRANSLATORS: Warning text during the installation. %s is a list of package
        error_message = _("These packages cannot be found in the software repositories:\n%s") %
          not_selected
        if suggest_y2log
          # TRANSLATORS: Error message, %d is replaced by the amount of failed packages.
          error_message += _("and %d additional packages") % (failed_count - MAX_PACKAGE_VIEW)
          # TRANSLATORS: Error message, %s is replaced by "/var/log/YaST2/y2log"
          error_message += "\n\n" + _("Details can be found in the %s file.") %
            "/var/log/YaST2/y2log"
        end

        Report.Error(error_message)
      end
    end

    publish function: :merge_product, type: "void (string)"
    publish variable: :Software, type: "map"
    publish variable: :patterns, type: "list <string>"
    publish variable: :kernel, type: "string"
    publish variable: :modified, type: "boolean"
    publish variable: :inst, type: "list <string>"
    publish variable: :all_xpatterns, type: "list <map <string, any>>"
    publish variable: :instsource, type: "string"
    publish function: :SetModified, type: "void ()"
    publish function: :GetModified, type: "boolean ()"
    publish function: :Import, type: "boolean (map)"
    publish function: :AutoinstSoftware, type: "void ()"
    publish function: :Export, type: "map ()"
    publish function: :AddModulePackages, type: "void (list <string>)"
    publish function: :AddYdepsFromProfile, type: "void (list <string>)"
    publish function: :RemoveModulePackages, type: "void (list <string>)"
    publish function: :Summary, type: "string ()"
    publish function: :autoinstPackages, type: "list <string> ()"
    publish function: :Write, type: "boolean ()"
    publish function: :pmInit, type: "void ()"
    publish function: :addPostPackages, type: "void (list <string>)"
    publish function: :ReadHelper, type: "map <string, any> ()"
    publish function: :Read, type: "boolean ()"

  private

    # Get user transacted packages, include only the packages in the requested state
    # @param status [Symbol] package status (:available, :selected, :installed,
    # :removed)
    # @return [Array<String>] package names
    def user_transact_packages(status)
      # only package names (without version)
      names_only = true
      packages = Pkg.GetPackages(status, names_only)

      # iterate over each package, Pkg.ResolvableProperties("", :package, "") requires a lot of
      # memory
      packages.select do |package|
        Pkg.PkgPropertiesAll(package).any? do |p|
          p["transact_by"] == :user && p["status"] == status
        end
      end
    end
  end

  AutoinstSoftware = AutoinstSoftwareClass.new
  AutoinstSoftware.main
end
