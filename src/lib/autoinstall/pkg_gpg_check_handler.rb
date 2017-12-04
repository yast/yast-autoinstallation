module Yast
  # This class will take the output from libzypp's pkgGpgCheck and will decide
  # if the package is suitable for installation or not according to the
  # AutoYaST profile.
  class PkgGpgCheckHandler
    include Yast::Logger

    # These are the check result values according to libzypp.
    # https://github.com/openSUSE/libzypp/blob/master/zypp/target/rpm/RpmDb.h
    CHK_OK         = 0 # Signature is OK
    CHK_NOTFOUND   = 1 # Signature type is unknown
    CHK_FAIL       = 2 # Signature does not verify
    CHK_NOTTRUSTED = 3 # Signature is OK but key is not trusted
    CHK_NOKEY      = 4 # Public key is unavailable
    CHK_ERROR      = 5 # File does not exist or can't be open
    CHK_NOSIG      = 6 # Signature is missing but digests are OK

    # This command will produce something which last line will be like:
    # DSA/SHA1, Mon 05 Oct 2015 04:24:50 PM WEST, Key ID 9b7d32f2d50582e6
    FIND_KEY_ID_CMD = "rpm --query --info --queryformat "\
      "\"%%|DSAHEADER?{%%{DSAHEADER:pgpsig}}:{%%|RSAHEADER?{%%{RSAHEADER:pgpsig}}:{(none}|}|\" "\
      " --package %s"

    attr_reader :result, :package, :path, :config

    # Constructor
    #
    # @param [Hash] data Output from `pkgGpgCheck` callback.
    # @option data [String] "CheckPackageResult" Check result code according to libzypp.
    # @option data [String] "Package" Package's name.
    # @option data [String] "Localpath" Path to RPM file.
    # @option data [String] "RepoMediaUrl" Media URL.
    #   (it should match `media_url` key in AutoYaST profile).
    # @param [Hash] profile AutoYaST profile.
    def initialize(data, profile)
      @result  = data["CheckPackageResult"]
      @package = data["Package"]
      @path    = data["Localpath"]
      @config  = get_addon_config(profile, data["RepoMediaUrl"])
      log.info format("Signature handling settings: #{@config}")
    end

    # Determine if the package should be accepted for installation or not
    def accept?
      case result
      when CHK_OK
        log.debug "Handling successful PGP checking"
        handle_ok
      when CHK_NOTFOUND, CHK_NOSIG
        log.debug "Handling unsigned package"
        handle_unsigned
      when CHK_NOKEY
        log.debug "Handling unknown PGP key"
        handle_unknown
      when CHK_FAIL
        log.debug "Handling verification failure"
        handle_failed
      when CHK_NOTTRUSTED
        log.debug "Handling non trusted PGP key"
        handle_nontrusted
      when CHK_ERROR
        log.debug "Handling error"
        handle_error
      else
        raise "Unknown GPG check result (#{result})for #{package}"
      end
    end

    private

    # Handle CHK_OK result
    #
    # Always returns true
    #
    # @return [Boolean] true
    def handle_ok
      true
    end

    # Handle the situation where the package is not signed
    #
    # If unsigned packages are allowed, it returns true.
    #
    # @return [Boolean] true if acceptable; otherwise false.
    def handle_unsigned
      config["accept_unsigned_file"] == true
    end

    # Handle the situation where verification failed
    #
    # if not verifiable packages are allowed, it returns true.
    #
    # @return [boolean] true if acceptable; otherwise false.
    def handle_failed
      config["accept_verification_failed"] == true
    end

    # Handle the situation where the GPG key is unknown
    #
    # If unknown GPG keys are acceptable, it returns true. On the other hand,
    # if packages key id is allowed, it also returns true. Otherwise, returns
    # false.
    #
    # @return [Boolean] true if acceptable; otherwise false.
    def handle_unknown
      section = config.fetch("accept_unknown_gpg_key", {})

      if section.kind_of?(Hash)
        section.fetch("all", false) == true ||
          section.fetch("keys", []).map(&:downcase).include?(find_key_id(path))
      else
        section == true
      end
    end

    # Handle the situation where the GPG key is non trusted
    #
    # If non trusted GPG keys are acceptable, it returns true. On the other
    # hand, if packages key id is allowed, it also returns true. Otherwise,
    # returns false.
    #
    # @return [Boolean] true if acceptable; otherwise false.
    def handle_nontrusted
      section = config.fetch("accept_non_trusted_gpg_key", {})

      if section.kind_of?(Hash)
        section.fetch("all", false) == true ||
          section.fetch("keys", []).map(&:downcase).include?(find_key_id(path))
      else
        section == true
      end
    end

    # Handle the situation where the package could not be open
    #
    # @return [Boolean] Always false.
    def handle_error
      false
    end

    private

    # Return add-on signature-handling settings
    #
    # If the add-on has its own specific configuration, those settings
    # will override to general settings.
    #
    # @param [Hash] profile AutoYaST profile
    # @param [String] url   Repository URL
    # @return [Hash] Signature handling settings for the given add-on.
    def get_addon_config(profile, url)
      addon_config = addons_config(profile).find { |c| c["media_url"] == url } || {}
      general_config = profile.fetch("general", {})
      general_config.fetch("signature-handling", {})
        .merge(addon_config.fetch("signature-handling", {}))
    end

    # Get add-ons configuration
    #
    # This is just a helper method that returns the //add-ons/add_on_products section
    # of an AutoYaST profile.
    #
    # @param [Hash] profile AutoYaST profile.
    # @return [Hash] Add-ons section from profile.
    def addons_config(profile)
      profile.fetch("add-on", {}).fetch("add_on_products", [])
    end

    # Find the key ID for the package
    #
    # It uses `rpm` to retrieve the key id.
    #
    # @param [String] path Path to RPM file.
    # @return [String, nil] Key id. It returns nil if could not be determined.
    def find_key_id(path)
      out = SCR.Execute(Yast::Path.new(".target.bash_output"), format(FIND_KEY_ID_CMD, path))
      key_id =
        if out["exit"].zero?
          out["stdout"].split("\n").last =~ /Key ID (\w+)/ ? Regexp.last_match(1).downcase : nil
        end
      log.debug("Key ID for #{package} (#{path}) is '#{key_id}'")
      key_id
    end
  end
end
