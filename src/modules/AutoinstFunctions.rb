require "y2packager/product"
require "y2packager/product_location"
require "y2packager/medium_type"

module Yast
  # Helper methods to be used on autoinstallation.
  class AutoinstFunctionsClass < Module
    include Yast::Logger

    def main
      textdomain "installation"

      Yast.import "Stage"
      Yast.import "Mode"
      Yast.import "AutoinstConfig"
      Yast.import "InstURL"
      Yast.import "ProductControl"
      Yast.import "Profile"
      Yast.import "Pkg"
    end

    # Determines if the second stage should be executed
    #
    # Checks Mode, AutoinstConfig and ProductControl to decide if it's
    # needed.
    #
    # FIXME: It's almost equal to InstFunctions.second_stage_required?
    # defined in yast2-installation, but exists to avoid a circular dependency
    # between packages (yast2-installation -> autoyast2-installation).
    #
    # @return [Boolean] 'true' if it's needed; 'false' otherwise.
    def second_stage_required?
      return false unless Stage.initial
      if (Mode.autoinst || Mode.autoupgrade) && !AutoinstConfig.second_stage
        Builtins.y2milestone("Autoyast: second stage is disabled")
        false
      else
        ProductControl.RunRequired("continue", Mode.mode)
      end
    end

    # Checking the environment the installed system
    # to run a second stage if it is needed.
    #
    # @return [String] empty String or error messsage about missing packages.
    def check_second_stage_environment
      error = ""
      return error unless second_stage_required?

      missing_packages = Profile.needed_second_stage_packages.select do |p|
        !Pkg.IsSelected(p)
      end
      unless missing_packages.empty?
        log.warn "Second stage cannot be run due missing packages: #{missing_packages}"
        # TRANSLATORS: %s will be replaced by a package list
        error = format(_("AutoYaST cannot run second stage due to missing packages \n%s.\n"),
          missing_packages.join(", "))
        unless registered?
          if Profile.current["suse_register"] &&
            Profile.current["suse_register"]["do_registration"] == true
            error << _("The registration has failed. " \
              "Please check your registration settings in the AutoYaST configuration file.")
            log.warn "Registration has been called but has failed."
          else
            error << _("You have not registered your system. " \
              "Missing packages can be added by configuring the registration in the AutoYaST configuration file.")
            log.warn "Registration is not configured at all."
          end
        end
      end
      error
    end

    # Tries to find a base product if could be identified from the AY profile
    #
    # There are several ways how can base product be defined in the profile
    # 1) explicitly
    # 2) impllicitly according to software selection
    # 3) if not set explicitly and just one product is available on media - use it
    #
    # @return [Y2Packager::Product] a base product or nil
    def selected_product
      return @selected_product if @selected_product

      profile = Profile.current
      product = identify_product_by_selection(profile)

      # user asked for a product which is not available -> exit, not found
      return nil if product.nil? && base_product_name(profile)

      @selected_product = if product
        log.info("selected_product - found explicitly defined base product: #{product.inspect}")
        product
      elsif (product = identify_product_by_patterns(profile))
        log.info("selected_product - base product identified by patterns: #{product.inspect}")
        product
      elsif (product = identify_product_by_packages(profile))
        log.info("selected_product - base product identified by packages: #{product.inspect}")
        product
      else
        # last instance
        base_products = Y2Packager::Product.available_base_products
        base_products.first if base_products.size == 1
      end

      @selected_product
    end

    def available_base_products
      @base_products ||= if Y2Packager::MediumType.offline?
      url = InstURL.installInf2Url("")
        Y2Packager::ProductLocation
          .scan(url)
          .select { |p| p.details && p.details.base }
          .sort(&::Y2Packager::PRODUCT_SORTER)
      else
        Y2Packager::Product.available_base_products
      end
    end

  private

    # Determine whether the system is registered
    #
    # @return [Boolean]
    def registered?
      require "registration/registration"
      Registration::Registration.is_registered?
    rescue LoadError
      false
    end

    # Tries to identify a base product according to the condition in block
    #
    # @return [Y2Packager::Product] a product if exactly one product matches
    # the criteria, nil otherwise
    def identify_product
      log.info "Found base products : #{available_base_products.inspect}"

      products = available_base_products.select do |product|
        if product.is_a?(Y2Packager::ProductLocation)
          yield(product.details.product)
        else
          yield(product.name)
        end
      end

      return products.first if products.size == 1
      nil
    end

    # Try to find base product according to patterns in profile
    #
    # searching for patterns like "sles-base-32bit"
    #
    # @param [Hash] profile - a hash representation of AY profile
    # @return [Y2Packager::Product] a product if exactly one product matches
    # the criteria, nil otherwise
    def identify_product_by_patterns(profile)
      software = profile["software"] || {}

      identify_product do |name|
        software.fetch("patterns", []).any? { |p| p =~ /#{name.downcase}-.*/ }
      end
    end

    # Try to find base product according to packages selection in profile
    #
    # searching for packages like "sles-release"
    #
    # @param [Hash] profile - a hash representation of AY profile
    # @return [Y2Packager::Product] a product if exactly one product matches
    # the criteria, nil otherwise
    def identify_product_by_packages(profile)
      software = profile["software"] || {}

      identify_product do |name|
        software.fetch("packages", []).any? { |p| p =~ /#{name.downcase}-release/ }
      end
    end

    # Try to identify base product using user's selection in profile
    #
    # @param [Hash] profile - a hash representation of AY profile
    # @return [Y2Packager::Product] a product if exactly one product matches
    # the criteria, nil otherwise
    def identify_product_by_selection(profile)
      identify_product do |name|
        name == base_product_name(profile)
      end
    end

    # Reads base product name from the profile
    #
    # FIXME: Currently it returns first found product name. It should be no
    # problem since this section was unused in AY installation so far.
    # However, it might be needed to add a special handling for multiple
    # poducts in the future. At least we can filter out products which are
    # not base products.
    #
    # @param profile [Hash] AutoYaST profile
    # @return [String] product name
    def base_product_name(profile)
      software = profile["software"]

      if software.nil?
        log.info("Error: given profile has not a valid software section")

        return nil
      end

      software.fetch("products", []).first
    end
  end

  AutoinstFunctions = AutoinstFunctionsClass.new
  AutoinstFunctions.main
end
