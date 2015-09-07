module Yast
  # Helper methods to be used on autoinstallation.
  class AutoinstFunctionsClass < Module
    def main
      textdomain "installation"

      Yast.import "Stage"
      Yast.import "Mode"
      Yast.import "AutoinstConfig"
      Yast.import "ProductControl"
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
  end

  AutoinstFunctions = AutoinstFunctionsClass.new
  AutoinstFunctions.main
end
