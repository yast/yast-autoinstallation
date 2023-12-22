# File:  modules/AutoInstall.ycp
# Package:  Auto-installation
# Summary:  Auto-installation related functions module
# Author:  Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"
require "autoinstall/pkg_gpg_check_handler"
require "autoinstall/dialogs/question"
require "installation/autoinst_issues"

module Yast
  class AutoInstallClass < Module
    include Yast::Logger

    # @return [::Installation::AutoinstIssues::List] AutoYaST issues list
    attr_accessor :issues_list

    def main
      textdomain "autoinst"

      Yast.import "Profile"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "AddOnProduct"
      Yast.import "AutoInstallRules"
      Yast.import "AutoinstConfig"
      Yast.import "AutoinstGeneral"
      Yast.import "Report"
      Yast.import "TFTP"

      @autoconf = false
      @issues_list = ::Installation::AutoinstIssues::List.new

      AutoInstall()
    end

    def callbackTrue_boolean_string(_dummy)
      true
    end

    def callbackFalse_boolean_string(_dummy)
      false
    end

    def callbackTrue_boolean_string_integer(_dummy, _dummy2)
      true
    end

    def callbackFalse_boolean_string_integer(_dummy, _dummy2)
      false
    end

    def callback_void_map(_dummy_map)
      nil
    end

    def callbackTrue_boolean_map(_dummy_map)
      true
    end

    def callbackFalse_boolean_map(_dummy_map)
      false
    end

    def callbackTrue_boolean_map_integer(_dummy_map, _dummy)
      true
    end

    def callbackFalse_boolean_map_integer(_dummy_map, _dummy)
      false
    end

    def callbackTrue_boolean_string_map_integer(_dummy, _dummy_map, _dummy_int)
      true
    end

    def callbackFalse_boolean_string_map_integer(_dummy, _dummy_map, _dummy_int)
      false
    end

    def callbackTrue_boolean_string_string(_dummy1, _dummy2)
      true
    end

    def callbackFalse_boolean_string_string(_dummy1, _dummy2)
      false
    end

    def callbackTrue_boolean_string_string_integer(_dummy1, _dummy2, _dummy3)
      true
    end

    def callbackFalse_boolean_string_string_integer(_dummy1, _dummy2, _dummy3)
      false
    end

    def callbackTrue_boolean_string_string_string(_dummy1, _dummy2, _dummy3)
      true
    end

    def callbackFalse_boolean_string_string_string(_dummy1, _dummy2, _dummy3)
      false
    end

    # Read saved data in continue mode
    # @return [Boolean] true on success
    def Continue
      #
      # First check if there are some other control files availabe
      # i.e. for post-installation only
      #
      if SCR.Read(path(".target.size"), AutoinstConfig.autoconf_file) == -1
        ret = Profile.ReadProfileStructure(AutoinstConfig.parsedControlFile)
        if Profile.current == {} || !ret
          Builtins.y2milestone("No saved autoinstall data found")
          false
        else
          Builtins.y2milestone("Found and read saved autoinst data")
          SCR.Execute(path(".target.remove"), AutoinstConfig.parsedControlFile)
          true
        end
      else
        Builtins.y2milestone(
          "XML Post installation data found: %1",
          AutoinstConfig.autoconf_file
        )
        ret = Profile.ReadXML(AutoinstConfig.autoconf_file)
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat(
            "/bin/mv %1 %2",
            AutoinstConfig.autoconf_file,
            AutoinstConfig.cache
          )
        )
        ret
      end
    end

    # Constructer
    # @return [void]
    def AutoInstall
      if Stage.cont
        ret = Continue()
        if ret && Ops.greater_than(Builtins.size(Profile.current), 0)
          if Mode.autoupgrade
            Builtins.y2milestone(
              "AutoYaST upgrade mode already set, keeping it"
            )
          else
            Builtins.y2milestone("Enabling Auto-Installation mode")
            Mode.SetMode("autoinstallation")
          end
        elsif Mode.autoinst
          Builtins.y2milestone(
            "No autoyast data found, switching back to manual installation"
          )
          Mode.SetMode("installation")
        elsif Mode.autoupgrade
          Builtins.y2milestone(
            "No autoyast data found, switching back to manual update"
          )
          Mode.SetMode("update")
        end
      elsif Stage.initial
        if SCR.Read(path(".target.size"), AutoinstConfig.xml_tmpfile) != -1 &&
            Builtins.size(Profile.current) == 0
          Builtins.y2milestone("autoyast: %1 found", AutoinstConfig.xml_tmpfile)
          # Profile is available and it has not been parsed yet.
          Profile.ReadXML(AutoinstConfig.xml_tmpfile)
        end
      end
      nil
    end

    # Save configuration
    # @return [Boolean] true on success
    def Save
      if Mode.autoinst || Mode.autoupgrade
        Profile.SaveProfileStructure(AutoinstConfig.parsedControlFile)
      else
        true
      end
    end

    # Finish Auto-Installation by saving misc files
    # @param [String] destdir
    # @return [void]
    def Finish(destdir)
      dircontents = Convert.to_list(
        SCR.Read(
          path(".target.dir"),
          Ops.add(AutoinstConfig.tmpDir, "/pre-scripts/")
        )
      )
      if Ops.greater_than(Builtins.size(dircontents), 0)
        SCR.Execute(
          path(".target.bash"),
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add("/bin/cp ", AutoinstConfig.tmpDir),
                "/pre-scripts/* "
              ),
              destdir
            ),
            AutoinstConfig.scripts_dir
          )
        )
        SCR.Execute(
          path(".target.bash"),
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add("/bin/cp ", AutoinstConfig.tmpDir),
                "/pre-scripts/logs/* "
              ),
              destdir
            ),
            AutoinstConfig.logs_dir
          )
        )
      end

      # copying ask-scripts and corresponding log files
      # to /var/adm/autoinstall
      SCR.Execute(path(".target.bash"),
        "/bin/cp #{AutoinstConfig.tmpDir}/ask-scripts/logs/*"\
        " #{destdir}#{AutoinstConfig.logs_dir}")
      SCR.Execute(path(".target.bash"),
        "/bin/cp #{AutoinstConfig.tmpDir}/ask-scripts/*"\
        " #{destdir}#{AutoinstConfig.scripts_dir}")
      SCR.Execute(path(".target.bash"),
        "/bin/cp #{AutoinstConfig.tmpDir}/ask-default-value-scripts/*"\
        " #{destdir}#{AutoinstConfig.scripts_dir}")

      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat(
          "/bin/cp %1 %2%3",
          AutoinstConfig.profile_path,
          destdir,
          AutoinstConfig.xml_file
        )
      )
      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat(
          "/bin/chmod 700 %1%2",
          destdir,
          AutoinstConfig.xml_file
        )
      )

      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat(
          "/bin/cp %1 %2%3",
          Ops.add(AutoinstConfig.profile_dir, "/pre-autoinst.xml"),
          destdir,
          AutoinstConfig.cache
        )
      )
      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat(
          "/bin/chmod 700 %1%2",
          destdir,
          Ops.add(AutoinstConfig.cache, "/pre-autoinst.xml")
        )
      )

      # Saving postpartitioning-scripts scripts/logs
      postpart_dir = AutoinstConfig.tmpDir + "/postpartitioning-scripts"
      if Yast::FileUtils.Exists(postpart_dir)
        SCR.Execute(
          path(".target.bash"),
          "/bin/cp #{postpart_dir}/* #{destdir}#{AutoinstConfig.scripts_dir}"
        )
        SCR.Execute(
          path(".target.bash"),
          "/bin/cp #{postpart_dir}/logs/* #{destdir}#{AutoinstConfig.logs_dir}"
        )
      end

      nil
    end

    # Put PXE file on the boot server using tftp
    # @return true on success
    def PXELocalBoot
      tmpdir = Convert.to_string(SCR.Read(path(".target.tmpdir")))
      hexfile = Builtins.sformat("%1/%2", tmpdir, AutoInstallRules.hostid)
      pxe = Ops.get_map(Profile.current, "pxe", {})
      dest_file = Ops.get_string(pxe, "filename", AutoInstallRules.hostid)
      if dest_file == "__MAC__"
        mac = AutoInstallRules.mac
        dest_file = Builtins.sformat(
          "01-%1-%2-%3-%4-%5-%6",
          Builtins.substring(mac, 0, 2),
          Builtins.substring(mac, 2, 2),
          Builtins.substring(mac, 4, 2),
          Builtins.substring(mac, 6, 2),
          Builtins.substring(mac, 8, 2),
          Builtins.substring(mac, 10, 2)
        )
      end
      server = Ops.get_string(pxe, "tftp-server", "")
      if server != "" && Ops.get_boolean(pxe, "pxe_localboot", false)
        Builtins.y2milestone(
          "putting pxe local boot file '%2' on server :%1",
          server,
          dest_file
        )
        config = Ops.get_string(pxe, "pxelinux-config", "")
        dir = Ops.get_string(pxe, "pxelinux-dir", "pxelinux.cfg")
        config = "DEFAULT linux\nLABEL linux\n  localboot 0" if config == ""

        SCR.Write(path(".target.string"), hexfile, config)

        return TFTP.Put(server, Ops.add(Ops.add(dir, "/"), dest_file), hexfile)
      end
      true
    end

    # Implement pkgGpgCheck callback
    #
    # @param [Hash] data Output from `pkgGpgCheck` callback.
    # @option data [String] "CheckPackageResult" Check result code according to libzypp.
    # @option data [String] "Package" Package's name.
    # @option data [String] "Localpath" Path to RPM file.
    # @option data [String] "RepoMediaUrl" Media URL.
    #   (it should match `media_url` key in AutoYaST profile).
    # @return [String] "I" if the package should be accepted; otherwise
    #   a blank string is returned (so no decision is made).
    def pkg_gpg_check(data)
      log.debug("pkgGpgCheck data: #{data}")
      checker = PkgGpgCheckHandler.new(
        data, Yast::AutoinstGeneral.signature_handling, Yast::AddOnProduct.add_on_products
      )
      accept = checker.accept?
      log.info("PkgGpgCheckerHandler for #{data["Package"]} returned #{accept}")
      accept ? "I" : ""
    end

    # Checking for valid imported values and there is an fatal error
    # we will stop the installation.
    #
    # @return [Boolean] True if the proposal is valid or the user accepted an invalid one.
    def valid_imported_values
      return true if @issues_list.empty?

      report_settings = Report.Export
      if @issues_list.fatal?
        # On fatal errors, the message should be displayed
        level = :error
        buttons_set = :abort
        display_message = true
        log_message = report_settings["errors"]["log"]
        timeout = report_settings["errors"]["timeout"]
      else
        # On non-fatal issues, obey report settings for warnings
        level = :warn
        buttons_set = :question
        display_message = report_settings["warnings"]["show"]
        log_message = report_settings["warnings"]["log"]
        timeout = report_settings["warnings"]["timeout"]
      end

      presenter = ::Installation::AutoinstIssues::IssuesPresenter.new(@issues_list)

      # Showing issues onetime only.
      @issues_list = ::Installation::AutoinstIssues::List.new

      log.send(level, presenter.to_plain) if log_message
      return true unless display_message

      dialog = Y2Autoinstallation::Dialogs::Question.new(
        _("AutoYaST configuration file check"),
        presenter.to_html,
        timeout:     timeout,
        buttons_set: buttons_set
      )
      dialog.run == :ok
    end

    publish variable: :autoconf, type: "boolean"
    publish function: :callbackTrue_boolean_string, type: "boolean (string)"
    publish function: :callbackFalse_boolean_string, type: "boolean (string)"
    publish function: :callbackTrue_boolean_string_integer, type: "boolean (string, integer)"
    publish function: :callbackFalse_boolean_string_integer, type: "boolean (string, integer)"
    publish function: :callback_void_map, type: "void (map <string, any>)"
    publish function: :callbackTrue_boolean_map, type: "boolean (map <string, any>)"
    publish function: :callbackFalse_boolean_map, type: "boolean (map <string, any>)"
    publish function: :callbackTrue_boolean_map_integer,
      type:     "boolean (map <string, any>, integer)"
    publish function: :callbackFalse_boolean_map_integer,
      type:     "boolean (map <string, any>, integer)"
    publish function: :callbackTrue_boolean_string_map_integer,
      type:     "boolean (string, map <string, any>, integer)"
    publish function: :callbackFalse_boolean_string_map_integer,
      type:     "boolean (string, map <string, any>, integer)"
    publish function: :callbackTrue_boolean_string_string, type: "boolean (string, string)"
    publish function: :callbackFalse_boolean_string_string, type: "boolean (string, string)"
    publish function: :callbackTrue_boolean_string_string_integer,
      type:     "boolean (string, string, integer)"
    publish function: :callbackFalse_boolean_string_string_integer,
      type:     "boolean (string, string, integer)"
    publish function: :callbackTrue_boolean_string_string_string,
      type:     "boolean (string, string, string)"
    publish function: :callbackFalse_boolean_string_string_string,
      type:     "boolean (string, string, string)"
    publish function: :Continue, type: "boolean ()"
    publish function: :AutoInstall, type: "void ()"
    publish function: :Save, type: "boolean ()"
    publish function: :Finish, type: "void (string)"
    publish function: :PXELocalBoot, type: "boolean ()"
    publish function: :pkg_gpg_check, type: "string (map)"
  end

  AutoInstall = AutoInstallClass.new
  AutoInstall.main
end
