# encoding: utf-8

# File:	modules/AutoInstall.ycp
# Package:	Auto-installation
# Summary:	Auto-installation related functions module
# Author:	Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"
require "autoinstall/pkg_gpg_check_handler"

module Yast
  class AutoInstallClass < Module
    def main
      textdomain "autoinst"

      Yast.import "Profile"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "AutoinstConfig"
      Yast.import "AutoInstallRules"
      Yast.import "Report"
      Yast.import "TFTP"

      @autoconf = false
      AutoInstall()
    end

    def callbackTrue_boolean_string(dummy)
      true
    end

    def callbackFalse_boolean_string(dummy)
      false
    end

    def callbackTrue_boolean_string_integer(dummy, dummy2)
      true
    end

    def callbackFalse_boolean_string_integer(dummy, dummy2)
      false
    end

    def callback_void_map(dummy_map)
      dummy_map = deep_copy(dummy_map)
      nil
    end

    def callbackTrue_boolean_map(dummy_map)
      dummy_map = deep_copy(dummy_map)
      true
    end

    def callbackFalse_boolean_map(dummy_map)
      dummy_map = deep_copy(dummy_map)
      false
    end

    def callbackTrue_boolean_map_integer(dummy_map, dummy)
      dummy_map = deep_copy(dummy_map)
      true
    end

    def callbackFalse_boolean_map_integer(dummy_map, dummy)
      dummy_map = deep_copy(dummy_map)
      false
    end

    def callbackTrue_boolean_string_map_integer(dummy, dummy_map, dummy_int)
      dummy_map = deep_copy(dummy_map)
      true
    end

    def callbackFalse_boolean_string_map_integer(dummy, dummy_map, dummy_int)
      dummy_map = deep_copy(dummy_map)
      false
    end

    def callbackTrue_boolean_string_string(dummy1, dummy2)
      true
    end

    def callbackFalse_boolean_string_string(dummy1, dummy2)
      false
    end

    def callbackTrue_boolean_string_string_integer(dummy1, dummy2, dummy3)
      true
    end

    def callbackFalse_boolean_string_string_integer(dummy1, dummy2, dummy3)
      false
    end

    def callbackTrue_boolean_string_string_string(dummy1, dummy2, dummy3)
      true
    end

    def callbackFalse_boolean_string_string_string(dummy1, dummy2, dummy3)
      false
    end

    # Read saved data in continue mode
    # @return [Boolean] true on success
    def Continue
      #
      # First check if there are some other control files availabe
      # i.e. for post-installation only
      #
      ret = false
      if SCR.Read(path(".target.size"), AutoinstConfig.autoconf_file) != -1
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
        return ret
      else
        ret = Profile.ReadProfileStructure(AutoinstConfig.parsedControlFile)
        if Profile.current == {} || !ret
          Builtins.y2milestone("No saved autoinstall data found")
          return false
        else
          Builtins.y2milestone("Found and read saved autoinst data")
          SCR.Execute(path(".target.remove"), AutoinstConfig.parsedControlFile)
          return true
        end
      end

      false
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
        return Profile.SaveProfileStructure(AutoinstConfig.parsedControlFile)
      else
        return true
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

      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat(
          "/bin/cp %1 %2%3",
          "/tmp/profile/autoinst.xml",
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
    # @options data [String] "CheckPackageResult" Check result code according to libzypp.
    # @options data [String] "Package" Package's name.
    # @options data [String] "Localpath" Path to RPM file.
    # @options data [String] "RepoMediaUrl" Media URL.
    #   (it should match `media_url` key in AutoYaST profile).
    # @return [String] "I" if the package should be accepted; otherwise
    #   a blank string is returned (so no decision is made).
    def pkg_gpg_check(data)
      log.debug("pkgGpgCheck data: #{data}")
      accept = PkgGpgCheckHandler.new(data, Profile.current).accept?
      log.info("PkgGpgCheckerHandler for #{data["Package"]} returned #{accept}")
      accept ? "I" : ""
    end

    publish :variable => :autoconf, :type => "boolean"
    publish :function => :callbackTrue_boolean_string, :type => "boolean (string)"
    publish :function => :callbackFalse_boolean_string, :type => "boolean (string)"
    publish :function => :callbackTrue_boolean_string_integer, :type => "boolean (string, integer)"
    publish :function => :callbackFalse_boolean_string_integer, :type => "boolean (string, integer)"
    publish :function => :callback_void_map, :type => "void (map <string, any>)"
    publish :function => :callbackTrue_boolean_map, :type => "boolean (map <string, any>)"
    publish :function => :callbackFalse_boolean_map, :type => "boolean (map <string, any>)"
    publish :function => :callbackTrue_boolean_map_integer, :type => "boolean (map <string, any>, integer)"
    publish :function => :callbackFalse_boolean_map_integer, :type => "boolean (map <string, any>, integer)"
    publish :function => :callbackTrue_boolean_string_map_integer, :type => "boolean (string, map <string, any>, integer)"
    publish :function => :callbackFalse_boolean_string_map_integer, :type => "boolean (string, map <string, any>, integer)"
    publish :function => :callbackTrue_boolean_string_string, :type => "boolean (string, string)"
    publish :function => :callbackFalse_boolean_string_string, :type => "boolean (string, string)"
    publish :function => :callbackTrue_boolean_string_string_integer, :type => "boolean (string, string, integer)"
    publish :function => :callbackFalse_boolean_string_string_integer, :type => "boolean (string, string, integer)"
    publish :function => :callbackTrue_boolean_string_string_string, :type => "boolean (string, string, string)"
    publish :function => :callbackFalse_boolean_string_string_string, :type => "boolean (string, string, string)"
    publish :function => :Continue, :type => "boolean ()"
    publish :function => :AutoInstall, :type => "void ()"
    publish :function => :Save, :type => "boolean ()"
    publish :function => :Finish, :type => "void (string)"
    publish :function => :PXELocalBoot, :type => "boolean ()"
    publish :function => :pkg_gpg_check, :type => "string (map)"

  end

  AutoInstall = AutoInstallClass.new
  AutoInstall.main
end
