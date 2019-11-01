module Yast
  class InstStoreUpgradeSoftwareClient < Client
    def main
      Yast.import "Pkg"
      Yast.import "GetInstArgs"
      Yast.import "Popup"
      Yast.import "Profile"
      Yast.import "Installation"

      return :auto if GetInstArgs.going_back

      # find out status of patterns
      @patterns = Pkg.ResolvableProperties("", :pattern, "") || []
      @patterns.select! do |p|
        Ops.get(p, "transact_by") == :user ||
          Ops.get(p, "transact_by") == :app_high
      end

      # note: does not matter if it is installed or to be installed, the resulting
      # state is the same; similar for uninstallation (valid for all packages, patterns
      # and products
      @patterns_to_remove = []
      @patterns_to_install = @patterns.map do |p|
        if Ops.get(p, "status") == :selected ||
            Ops.get(p, "status") == :installed
          next Ops.get_string(p, "name", "")
        elsif Ops.get(p, "status") == :removed ||
            Ops.get(p, "status") == :available
          @patterns_to_remove = Builtins.add(
            @patterns_to_remove,
            Ops.get_string(p, "name", "")
          )
        end

        nil
      end
      @patterns_to_install.compact!
      Builtins.y2milestone("Patterns to install: %1", @patterns_to_install)
      Builtins.y2milestone("Patterns to remove: %1", @patterns_to_remove)

      @packages_to_remove = transactional_packages(:removed).concat(
        transactional_packages(:available)
      )
      @packages_to_install = transactional_packages(:selected).concat(
        transactional_packages(:installed)
      )

      Builtins.y2milestone("Packages to install: %1", @packages_to_install)
      Builtins.y2milestone("Packages to remove: %1", @packages_to_remove)

      # find out status of products
      @products = Pkg.ResolvableProperties("", :product, "") || []
      @products.select! do |p|
        Ops.get(p, "transact_by") == :user ||
          Ops.get(p, "transact_by") == :app_high
      end

      @products_to_remove = []
      @products_to_install = @products.map do |p|
        if Ops.get(p, "status") == :selected ||
            Ops.get(p, "status") == :installed
          next Ops.get_string(p, "name", "")
        elsif Ops.get(p, "status") == :removed ||
            Ops.get(p, "status") == :available
          @products_to_remove = Builtins.add(
            @products_to_remove,
            Ops.get_string(p, "name", "")
          )
        end

        nil
      end
      @products_to_install.compact!
      Builtins.y2milestone("Products to install: %1", @products_to_install)
      Builtins.y2milestone("Products to remove: %1", @products_to_remove)

      @software = {
        "packages"        => @packages_to_install,
        "patterns"        => @patterns_to_install,
        "products"        => @products_to_install,
        "remove-packages" => @packages_to_remove,
        "remove-patterns" => @patterns_to_remove,
        "remove-products" => @products_to_remove
      }

      Ops.set(Profile.current, "software", @software)
      # /root exists during upgrade
      Profile.Save(Ops.add(Installation.destdir, "/root/autoupg_updated.xml"))

      :auto
    end

  private

    # get packages which are in requested state, ignore the packages changed
    # by the solver
    # @param status [Symbol] package status (:available, :selected, :installed,
    # :removed)
    # @return [Array<String>] package names
    def transactional_packages(status)
      # only package names (without version)
      names_only = true
      names = Pkg.GetPackages(status, names_only)

      names.select do |name|
        Pkg.PkgPropertiesAll(name).any? do |p|
          (p["transact_by"] == :user || p["transact_by"] == :app_high) &&
            p["status"] == status
        end
      end
    end
  end
end

Yast::InstStoreUpgradeSoftwareClient.new.main
