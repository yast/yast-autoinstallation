module Yast
  # Helper methods to be used on autoinstallation.
  class AutoinstFunctionsClass < Module
    include Yast::Logger

    def main
      textdomain "installation"

      Yast.import "Stage"
      Yast.import "Mode"
      Yast.import "AutoinstConfig"
      Yast.import "ProductControl"
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

  end

  AutoinstFunctions = AutoinstFunctionsClass.new
  AutoinstFunctions.main
end
