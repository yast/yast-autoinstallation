# encoding: utf-8

# File:	modules/AutoinstConfig.ycp
# Module:	Auto-Installation
# Summary:	This module handles the configuration for auto-installation
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"
require "y2packager/product"

module Yast
  import "ServicesManagerTarget"

  class AutoinstConfigClass < Module

    module Target
      include ServicesManagerTargetClass::BaseTargets
    end

    DEFAULT_PROFILE_NAME = "autoinst.xml".freeze

    include Yast::Logger

    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.import "Misc"
      Yast.import "Mode"
      Yast.import "Installation"
      Yast.import "URL"
      Yast.import "SLP"
      Yast.import "Stage"
      Yast.import "Label"
      Yast.import "Report"
      Yast.import "Profile"
      Yast.import "AutoinstFunctions"
      Yast.import "Pkg"

      Yast.include self, "autoinstall/xml.rb"



      @runModule = ""

      # Profile Repository
      @Repository = ""

      @ProfileEncrypted = false
      @ProfilePassword = ""

      # Package Repository
      @PackageRepository = ""

      # Classes
      @classDir = ""

      # Current file name
      @currentFile = ""

      #
      # Temporary directory for storing profile before installation starts
      #
      @tmpDir = Convert.to_string(SCR.Read(path(".target.tmpdir")))

      #
      # Main directory for data generated during installation
      #
      @var_dir = "/var/adm/autoinstall"

      #
      # Directory for the pre/post and chroot scripts
      #
      @scripts_dir = Ops.add(@var_dir, "/scripts")
      @initscripts_dir = Ops.add(@var_dir, "/init.d")

      #
      # Directory where log files of pre/post and chroot scripts are kept
      #
      @logs_dir = Ops.add(@var_dir, "/logs")

      #
      # Destination dir
      #
      @destdir = Installation.destdir


      #
      # Cache directory
      #
      @cache = Ops.add(@var_dir, "/cache")

      #
      # Temporary file name for retrieved system profile
      #
      @xml_tmpfile = Ops.add(@tmpDir, "/autoinst.xml")

      #
      # Final location for retrieved system profile
      #
      @xml_file = Ops.add(@cache, "/installedSystem.xml")


      #
      # Direcotry for runtime operation data
      #
      @runtime_dir = "/var/lib/autoinstall"

      #
      # Directory where complete configuration files are kept.
      #
      @files_dir = Ops.add(@var_dir, "/files")

      #
      # Directory to store profile for possible user manipulation.
      #
      @profile_dir = "/tmp/profile"

      #
      # The user  modified version of the Profile
      #
      @modified_profile = Ops.add(@profile_dir, "/modified.xml")


      @autoconf_file = Ops.add(@runtime_dir, "/autoconf/autoconf.xml")

      #
      # Parsed data from XML control in YCP format
      #
      @parsedControlFile = Ops.add(@cache, "/autoinst.ycp")


      @remote_rules_location = "rules/rules.xml"
      @local_rules_location = Ops.add(@tmpDir, "/rules")
      @local_rules_file = Ops.add(@local_rules_location, "/rules.xml")

      # Data from command line
      @urltok = {}

      @scheme = ""
      @host = ""
      @filepath = ""
      @directory = ""
      @port = ""
      @user = ""
      @pass = ""


      #
      # Default systemd target
      #
      @default_target = Target::GRAPHICAL


      #
      # Confirm installation
      #
      @Confirm = true

      #
      # S390
      #
      @cio_ignore = true

      # Running autoyast second_stage
      @second_stage = true

      # Network is configured during the first stage before the proposal
      @network_before_proposal = false

      @OriginalURI = ""

      @message = ""

      # Class merging.
      # lists not to be merged, instead they will be "added"
      #
      @dontmerge = []

      # the "writo setting now" button is disabled for there modules
      #
      #
      @noWriteNow = []

      #
      # Halt after initial phase
      #
      @Halt = false

      #
      # Dont Hard Reboot
      #
      @ForceBoot = false

      #
      # Show Reboot Message
      #
      @RebootMsg = false

      #
      # AutoYaST profile is stored in the root partition (for upgrade)
      #
      @ProfileInRootPart = false


      #
      # remote profile (invented for pre-probing of s390)
      # in case of a remote profile, the profile can be fetched
      # before the probing stage DASD module can has run
      #
      @remoteProfile = true
      @Proposals = []

      #
      # LeanOS: a base product explicitly selected by user in the profile
      #
      @selected_product = nil

      Yast.include self, "autoinstall/io.rb"
      AutoinstConfig()
    end

    def getProposalList
      deep_copy(@Proposals)
    end
    def setProposalList(l)
      l = deep_copy(l)
      @Proposals = deep_copy(l)

      nil
    end

    # Checking the environment the installed system
    # to run a second stage if it is needed.
    #
    # @return [String] empty String or error messsage about missing packages.
    def check_second_stage_environment
      error = ""
      return error unless AutoinstFunctions.second_stage_required?

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

    # Searches for 'autoyast' via SLP and returns the full URL of
    # the profile. If more providers are found, user is asked to
    # select one.
    #
    # FIXME: This function has been intentionally left (almost) intact
    # and needs refactoring
    #
    # @return [String] profile location or 'nil' if nothing is found
    def find_slp_autoyast
      profile_location = nil

      slpData = SLP.FindSrvs("autoyast", "")

      # SLP data returned by SLP server contain the service ID, colon
      # and then the URL of that service
      url_starts_at = "service.autoyast:".size

      # More providers to choose from
      if Ops.greater_than(Builtins.size(slpData), 1)
        dummy = []
        comment2url = {}
        Builtins.foreach(slpData) do |m|
          attrList = SLP.FindAttrs(Ops.get_string(m, "srvurl", ""))

          if Ops.greater_than(Builtins.size(attrList), 0)
            url = Builtins.substring(Ops.get_string(m, "srvurl", ""), url_starts_at)
            # FIXME: that's really lazy coding here but I allow only one attribute currently anyway
            #        so it's lazy but okay. No reason to be too strict here with the checks
            #        As soon as more than one attr is possible, I need to iterate over the attr list
            #
            comment = Ops.get(attrList, 0, "")
            # The line above needs to be fixed when we have more attributes

            # comment will look like this: "(description=BLA BLA)"
            startComment = Builtins.findfirstof(comment, "=")
            endComment = Builtins.findlastof(comment, ")")

            if startComment != nil && endComment != nil &&
              Ops.greater_than(
                Ops.subtract(Ops.subtract(endComment, startComment), 1),
                0
              )
              comment = Builtins.substring(
                comment,
                Ops.add(startComment, 1),
                Ops.subtract(Ops.subtract(endComment, startComment), 1)
              )
            else
              comment = ""
            end

            if Ops.less_than(Builtins.size(comment), 1)
              comment = Builtins.sformat(
                "bad description in SLP for %1",
                url
              )
            end

            dummy = Builtins.add(dummy, Item(comment, false))
            Ops.set(comment2url, comment, url)
          else
            url = Builtins.substring(Ops.get_string(m, "srvurl", ""), url_starts_at)
            dummy = Builtins.add(dummy, Item(url, false))
            Ops.set(comment2url, url, url)
          end
        end

        dlg = Left(ComboBox(Id(:choose), _("Choose Profile"), dummy))

        UI.OpenDialog(VBox(dlg, PushButton(Id(:ok), Label.OKButton)))
        UI.UserInput

        profile_location = Ops.get(
          comment2url,
          Convert.to_string(UI.QueryWidget(Id(:choose), :Value)),
          ""
        )

        UI.CloseDialog

      # just one provider
      elsif Builtins.size(slpData) == 1
        profile_location = Builtins.substring(
          Ops.get_string(slpData, [0, "srvurl"], ""),
          17
        )

      # Nothing returned by SLP query
      else
        log.error "slp query for 'autoyast' failed"
        Report.Error(_("No 'autoyast' provider has been found via SLP."))
      end

      profile_location
    end

    # Updates or extends the profile location according to defaults
    # @param profile_location [String] AutoYast profile location as defined on commandline
    # @return [String] updated profile location
    def update_profile_location(profile_location)
      if profile_location.nil? || profile_location == ""
        # FIXME: reevaluate this statement
        #
        # Autoinstall mode was not activated from command line.
        # There must be a floppy with an 'autoinst.xml' in order
        # to be able to reach this point, so we set floppy with
        # autoinst.xml as the control file.
        profile_location = "floppy:///#{DEFAULT_PROFILE_NAME}"
      elsif profile_location == "default"
        profile_location = "file:///#{DEFAULT_PROFILE_NAME}"
      # bsc#987858: autoyast=usb checks for the default profile
      elsif profile_location == "usb"
        profile_location = "usb:///#{DEFAULT_PROFILE_NAME}"
      elsif profile_location == "slp"
        profile_location = find_slp_autoyast
      else
        profile_location
      end
    end

    # Processes location of the profile given as a parameter.
    # @param profile_location [String] AutoYast profile location as defined on commandline
    # @example autoyast=http://www.server.com/profiles/
    # Fills internal variables
    def ParseCmdLine(profile_location)

      log.info "AutoYast profile location #{profile_location}"

      profile_location = update_profile_location(profile_location)
      # There is no profile defined/found anywhere
      return false if profile_location.nil?

      parsed_url = URL.Parse(profile_location)

      if parsed_url["scheme"].nil? || parsed_url["scheme"] == ""
        Report.Error(_("Invalid AutoYaST profile URL\n%{url}") % {:url => profile_location})
        return false
      end

      @OriginalURI = profile_location
      @urltok = deep_copy(parsed_url)

      @scheme   = parsed_url["scheme"] || "default"
      @host     = parsed_url["host"]   || ""
      @filepath = parsed_url["path"]   || ""
      @port     = parsed_url["port"]   || ""
      @user     = parsed_url["user"]   || ""
      @pass     = parsed_url["pass"]   || ""

      @remoteProfile = !["default", "file", "floppy", "usb", "device"].include?(@scheme)

      log.info "urltok = #{URL.HidePassword(profile_location)}"
      true
    end



    # SetProtocolMessage ()
    # @return [void]

    def SetProtocolMessage
      if @scheme == "floppy"
        @message = _("Retrieving control file from floppy.")
      elsif @scheme == "tftp"
        @message = Builtins.sformat(
          _("Retrieving control file (%1) from TFTP server: %2."),
          @filepath,
          @host
        )
      elsif @scheme == "nfs"
        @message = Builtins.sformat(
          _("Retrieving control file (%1) from NFS server: %2."),
          @filepath,
          @host
        )
      elsif @scheme == "http"
        @message = Builtins.sformat(
          _("Retrieving control file (%1) from HTTP server: %2."),
          @filepath,
          @host
        )
      elsif @scheme == "ftp"
        @message = Builtins.sformat(
          _("Retrieving control file (%1) from FTP server: %2."),
          @filepath,
          @host
        )
      elsif @scheme == "file"
        @message = Builtins.sformat(
          _("Copying control file from file: %1."),
          @filepath
        )
      elsif @scheme == "device"
        @message = Builtins.sformat(
          _("Copying control file from device: /dev/%1."),
          @filepath
        )
      elsif @scheme == "default"
        @message = _("Copying control file from default location.")
      else
        @message = _("Source unknown.")
      end
      nil
    end


    # Save Configuration global settings
    # @return	[void]
    def Save
      # Write sysconfig variables.
      Builtins.y2milestone("Saving configuration data")

      SCR.Write(path(".sysconfig.autoinstall.REPOSITORY"), @Repository)
      SCR.Write(path(".sysconfig.autoinstall.CLASS_DIR"), @classDir)

      nil
    end

    # escape a string so it can be passed to a shell
    # @return escaped string string
    def ShellEscape(s)
      i = 0
      res = ""

      while Ops.less_than(i, Builtins.size(s))
        c = Builtins.substring(s, i, 1)
        c = Ops.add("\\", c) if c == "\"" || c == "$" || c == "\\" || c == "`"
        res = Ops.add(res, c)
        i = Ops.add(i, 1)
      end
      res
    end

    # Constructor
    # @return [void]
    def AutoinstConfig
      if (Mode.autoinst || Mode.autoupgrade) && Stage.initial
        autoinstall = SCR.Read(path(".etc.install_inf.AutoYaST"))
        if autoinstall != nil && Ops.is_string?(autoinstall)
          ParseCmdLine(Convert.to_string(autoinstall))
          Builtins.y2milestone("cmd line=%1", autoinstall)
          SetProtocolMessage()
        end
      elsif Mode.config
        # Load configuration data from /etc/sysconfig/autoinstall
        @Repository = Misc.SysconfigRead(
          path(".sysconfig.autoinstall.REPOSITORY"),
          "/var/lib/autoinstall/repository/"
        )
        @classDir = Misc.SysconfigRead(
          path(".sysconfig.autoinstall.CLASS_DIR"),
          Ops.add(@Repository, "/classes")
        )
        tmp_dontmerge = Misc.SysconfigRead(
          path(".sysconfig.autoinstall.XSLT_DONTMERGE"),
          "addon,conf"
        )
        tmp_no_writenow = Misc.SysconfigRead(
          path(".sysconfig.autoinstall.FORBID_WRITENOW"),
          "add-on,suse_register,partitioning,bootloader,general,report"
        )

        @dontmerge = Builtins.splitstring(tmp_dontmerge, ",")
        @noWriteNow = Builtins.splitstring(tmp_no_writenow, ",")

        # Set the defaults, just in case.
        if @Repository == "" || @Repository == nil
          @Repository = "/var/lib/autoinstall/repository"
        end
      end
      #This probably gets never executed and it only breaks the commandline iface
      #by Mode::test() call which instantiates UI
      # else if (Mode::test () && Mode::normal ())
      # {
      #     local_rules_file = (string)WFM::Args(1);
      # }
      nil
    end

    def MainHelp
      main_help = _(
        "<h3>AutoYaST Configuration Management System</h3>\n" +
          "<p>Almost all resources of the control file can be\n" +
          "configured using the configuration management system.</p>\n"
      ) +
        _(
          "<p>Most of the modules used to create the configuration are identical to those available\n" +
            "through the YaST Control Center. Instead of configuring this system, the data\n" +
            "entered is collected and exported to the control file that can be used to\n" +
            "install another system using AutoYaST.\n" +
            "</p>\n"
        ) +
        _(
          "<p>In addition to the existing and familiar modules,\n" +
            "new interfaces were created for special and complex configurations, including\n" +
            "partitioning, general options, and software.</p>\n"
        )
      main_help
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

    # Profile path during installation
    #
    # @return [String] Path
    def profile_path
      File.join(profile_dir, DEFAULT_PROFILE_NAME)
    end

    # Profile backup path during installation
    #
    # @return [String] Path
    def profile_backup_path
      File.join(profile_dir, "pre-autoinst.xml")
    end

    publish :variable => :runModule, :type => "string"
    publish :variable => :Repository, :type => "string"
    publish :variable => :ProfileEncrypted, :type => "boolean"
    publish :variable => :ProfilePassword, :type => "string"
    publish :variable => :PackageRepository, :type => "string"
    publish :variable => :classDir, :type => "string"
    publish :variable => :currentFile, :type => "string"
    publish :variable => :tmpDir, :type => "string"
    publish :variable => :var_dir, :type => "string"
    publish :variable => :scripts_dir, :type => "string"
    publish :variable => :initscripts_dir, :type => "string"
    publish :variable => :logs_dir, :type => "string"
    publish :variable => :destdir, :type => "string"
    publish :variable => :cache, :type => "string"
    publish :variable => :xml_tmpfile, :type => "string"
    publish :variable => :xml_file, :type => "string"
    publish :variable => :runtime_dir, :type => "string"
    publish :variable => :files_dir, :type => "string"
    publish :variable => :profile_dir, :type => "string"
    publish :variable => :modified_profile, :type => "string"
    publish :variable => :autoconf_file, :type => "string"
    publish :variable => :parsedControlFile, :type => "string"
    publish :variable => :remote_rules_location, :type => "string"
    publish :variable => :local_rules_location, :type => "string"
    publish :variable => :local_rules_file, :type => "string"
    publish :variable => :urltok, :type => "map"
    publish :variable => :scheme, :type => "string"
    publish :variable => :host, :type => "string"
    publish :variable => :filepath, :type => "string"
    publish :variable => :directory, :type => "string"
    publish :variable => :port, :type => "string"
    publish :variable => :user, :type => "string"
    publish :variable => :pass, :type => "string"
    publish :variable => :default_target, :type => "string"
    publish :variable => :Confirm, :type => "boolean"
    publish :variable => :cio_ignore, :type => "boolean"
    publish :variable => :second_stage, :type => "boolean"
    publish :variable => :network_before_proposal, :type => "boolean"
    publish :variable => :OriginalURI, :type => "string"
    publish :variable => :message, :type => "string"
    publish :variable => :dontmerge, :type => "list <string>"
    publish :variable => :noWriteNow, :type => "list <string>"
    publish :variable => :Halt, :type => "boolean"
    publish :variable => :ForceBoot, :type => "boolean"
    publish :variable => :RebootMsg, :type => "boolean"
    publish :variable => :ProfileInRootPart, :type => "boolean"
    publish :variable => :remoteProfile, :type => "boolean"
    publish :variable => :Proposals, :type => "list <string>"
    publish :function => :getProposalList, :type => "list <string> ()"
    publish :function => :setProposalList, :type => "void (list <string>)"
    publish :function => :ParseCmdLine, :type => "boolean (string)"
    publish :function => :SetProtocolMessage, :type => "void ()"
    publish :function => :Save, :type => "void ()"
    publish :function => :ShellEscape, :type => "string (string)"
    publish :function => :AutoinstConfig, :type => "void ()"
    publish :function => :MainHelp, :type => "string ()"
    publish :function => :check_second_stage_environment, :type => "string ()"

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
      software = profile.fetch("software", {})
      software.fetch("products", []).first
    end

    # Tries to identify a base product according to the condition in block
    #
    # @return [Y2Packager::Product] a product if exactly one product matches
    # the criteria, nil otherwise
    def identify_product
      base_products = Y2Packager::Product.available_base_products

      products = base_products.select do |product|
        yield(product)
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
      software = profile.fetch("software", {})

      identify_product do |product|
        software.fetch("patterns", []).any? { |p| p =~ /#{product.name.downcase}-.*/ }
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
      software = profile.fetch("software", {})

      identify_product do |product|
        software.fetch("packages", []).any? { |p| p =~ /#{product.name.downcase}-release/ }
      end
    end

    # Try to identify base product using user's selection in profile
    #
    # @param [Hash] profile - a hash representation of AY profile
    # @return [Y2Packager::Product] a product if exactly one product matches
    # the criteria, nil otherwise
    def identify_product_by_selection(profile)
      identify_product do |product|
        product.short_name == base_product_name(profile)
      end
    end
  end

  AutoinstConfig = AutoinstConfigClass.new
  AutoinstConfig.main
end
