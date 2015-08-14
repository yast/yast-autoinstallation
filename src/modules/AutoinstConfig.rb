# encoding: utf-8

# File:	modules/AutoinstConfig.ycp
# Module:	Auto-Installation
# Summary:	This module handles the configuration for auto-installation
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"

module Yast
  import "ServicesManagerTarget"

  class AutoinstConfigClass < Module

    module Target
      include ServicesManagerTargetClass::BaseTargets
    end

    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.import "Misc"
      Yast.import "Mode"
      Yast.import "Installation"
      Yast.import "URL"
      Yast.import "SLP"
      Yast.import "Stage"

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


    # Return location of profile from command line.
    # @return [Hash] with protocol, server, path
    # @example autoyast=http://www.server.com/profiles/
    def ParseCmdLine(autoinstall)
      Yast.import "URL"

      result = {}
      cmdLine = ""

      if Ops.greater_than(Builtins.size(autoinstall), 0)
        cmdLine = autoinstall
        if cmdLine == "default"
          Ops.set(result, "scheme", "file")
          Ops.set(result, "path", "/autoinst.xml")
        else
          if cmdLine == "slp"
            slpData = SLP.FindSrvs("autoyast", "")
            if Ops.greater_than(Builtins.size(slpData), 1)
              dummy = []
              comment2url = {}
              Builtins.foreach(slpData) do |m|
                attrList = SLP.FindAttrs(Ops.get_string(m, "srvurl", ""))
                if Ops.greater_than(Builtins.size(attrList), 0)
                  url = Builtins.substring(Ops.get_string(m, "srvurl", ""), 17)
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
                  url = Builtins.substring(Ops.get_string(m, "srvurl", ""), 17)
                  dummy = Builtins.add(dummy, Item(url, false))
                  Ops.set(comment2url, url, url)
                end
              end
              dlg = Left(ComboBox(Id(:choose), _("Choose Profile"), dummy))
              UI.OpenDialog(VBox(dlg, PushButton(Id(:ok), "Ok")))
              UI.UserInput
              cmdLine = Ops.get(
                comment2url,
                Convert.to_string(UI.QueryWidget(Id(:choose), :Value)),
                ""
              )
              UI.CloseDialog
            elsif Builtins.size(slpData) == 1
              cmdLine = Builtins.substring(
                Ops.get_string(slpData, [0, "srvurl"], ""),
                17
              )
            else
              cmdLine = "slp query for 'autoyast' failed"
            end
          end
          result = URL.Parse(cmdLine)
          @OriginalURI = cmdLine
        end
      end


      if Ops.get_string(result, "scheme", "") == ""
        # Autoinstall mode was not activated from command line.
        # There must be a floppy with an 'autoinst.xml' in order
        # to be able to reach this point, so we set floppy with
        # autoinst.xml as the control file.

        result = Builtins.add(result, "scheme", "floppy")
        result = Builtins.add(result, "path", "/autoinst.xml")
      end
      @urltok = deep_copy(result)

      @scheme = Ops.get_string(@urltok, "scheme", "default")
      @host = Ops.get_string(@urltok, "host", "")
      @filepath = Ops.get_string(@urltok, "path", "")
      @port = Ops.get_string(@urltok, "port", "")
      @user = Ops.get_string(@urltok, "user", "")
      @pass = Ops.get_string(@urltok, "pass", "")

      if @scheme == "default" || @scheme == "file" || @scheme == "floppy"
        @remoteProfile = false
      end
      Builtins.y2milestone("urltok = %1", @urltok)
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
  end

  AutoinstConfig = AutoinstConfigClass.new
  AutoinstConfig.main
end
