module Y2Autoinstallation
  module AutoinstIssues
    # Base class for autoinstallation problems while importing the
    # AutoYaST configuration file.
    #
    # Y2Autoinstallation::AutoinstIssues offers an API to register
    # and report related AutoYaST problems.
    class Issue
      include Yast::I18n

      # @return [String] Section where it was detected
      attr_reader :section

      # @return [Symbol] :warn, :fatal problem severity
      attr_reader :severity

      # Return problem severity
      #
      # * :fatal: abort the installation.
      # * :warn:  display a warning.
      #
      # @return [Symbol] Issue severity (:warn, :fatal)
      # @raise NotImplementedError
      def severity
        @severity || :warn
      end

      # Return the error message to be displayed
      #
      # @return [String] Error message
      # @raise NotImplementedError
      def message
        raise NotImplementedError
      end

      # Determine whether an error is fatal
      #
      # This is just a convenience method.
      #
      # @return [Boolean]
      def fatal?
        severity == :fatal
      end

      # Determine whether an error is just a warning
      #
      # This is just a convenience method.
      #
      # @return [Boolean]
      def warn?
        severity == :warn
      end
    end
  end
end
