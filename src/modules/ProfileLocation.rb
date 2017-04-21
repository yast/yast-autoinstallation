# encoding: utf-8

# File:	modules/ProfileLocation.ycp
# Package:	Auto-installation
# Summary:	Process Auto-Installation Location
# Author:	Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"

module Yast
  class ProfileLocationClass < Module
    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.import "AutoinstConfig"
      Yast.import "AutoInstallRules"

# storage-ng
=begin
      Yast.import "StorageDevices"
      Yast.import "StorageControllers"
=end

      Yast.import "Mode"
      Yast.import "Installation"
      Yast.import "Report"
      Yast.import "Label"
      Yast.import "URL"


      Yast.include self, "autoinstall/autoinst_dialogs.rb"
      Yast.include self, "autoinstall/io.rb"
      ProfileLocation()
    end

    # Constructor
    # @return [void]
    def ProfileLocation
      nil
    end


    # Initiate retrieving of control files and Rules.
    # @return [Boolean]
    def Process
      ok = false
      ret = false

      Builtins.y2milestone(
        "Path to remote control file: %1",
        AutoinstConfig.filepath
      )

      localfile = AutoinstConfig.xml_tmpfile

      is_directory = false

      if AutoinstConfig.scheme == "relurl"
        # FIXME:
        # file                  # local file

        AutoinstConfig.scheme = Convert.to_string(
          SCR.Read(path(".etc.install_inf.InstMode"))
        )
        if AutoinstConfig.scheme == "hd" || AutoinstConfig.scheme == "harddisk" ||
            AutoinstConfig.scheme == "disk"
          part = Convert.to_string(SCR.Read(path(".etc.install_inf.Partition")))
          AutoinstConfig.scheme = "device"
          AutoinstConfig.host = part
          AutoinstConfig.filepath = Ops.add(
            Ops.add(
              Convert.to_string(SCR.Read(path(".etc.install_inf.Serverdir"))),
              "/"
            ),
            AutoinstConfig.filepath
          )
        else
          if AutoinstConfig.scheme == "cd" || AutoinstConfig.scheme == "cdrom"
            AutoinstConfig.scheme = "file"
          end
          if Ops.greater_than(Builtins.size(AutoinstConfig.filepath), 0)
            AutoinstConfig.filepath = Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    Convert.to_string(
                      SCR.Read(path(".etc.install_inf.Serverdir"))
                    ),
                    "/"
                  ),
                  AutoinstConfig.host
                ),
                "/"
              ),
              AutoinstConfig.filepath
            )
          else
            AutoinstConfig.filepath = Ops.add(
              Ops.add(
                Convert.to_string(SCR.Read(path(".etc.install_inf.Serverdir"))),
                "/"
              ),
              AutoinstConfig.host
            )
          end
          if Convert.to_string(SCR.Read(path(".etc.install_inf.Server"))) != nil
            AutoinstConfig.host = Convert.to_string(
              SCR.Read(path(".etc.install_inf.Server"))
            )
          end
        end

        Builtins.y2milestone(
          "relurl for profile changed to: %1://%2%3",
          AutoinstConfig.scheme,
          AutoinstConfig.host,
          AutoinstConfig.filepath
        )
        SCR.Write(
          path(".etc.install_inf.ayrelurl"),
          Builtins.sformat(
            "%1://%2/%3",
            AutoinstConfig.scheme,
            AutoinstConfig.host,
            AutoinstConfig.filepath
          )
        )
        SCR.Write(path(".etc.install_inf"), nil)
      elsif AutoinstConfig.scheme == "label"
        Builtins.y2milestone("searching label")
        Builtins.foreach(Storage.GetTargetMap) do |device, v|
          Builtins.y2milestone("looking on %1", device)
          if Ops.get_string(v, "label", "") == AutoinstConfig.host
            AutoinstConfig.scheme = "device"
            AutoinstConfig.host = Builtins.substring(device, 5)
            Builtins.y2milestone("found on %1", AutoinstConfig.host)
            raise Break
          end
          Builtins.foreach(Ops.get_list(v, "partitions", [])) do |p|
            if Ops.get_string(p, "label", "") == AutoinstConfig.host
              AutoinstConfig.scheme = "device"
              AutoinstConfig.host = Builtins.substring(
                Ops.get_string(p, "device", device),
                5
              )
              Builtins.y2milestone("found on %1", AutoinstConfig.host)
              raise Break
            end
            Builtins.y2milestone(
              "not found on %1",
              Ops.get_string(p, "device", "hm?")
            )
          end
          raise Break if AutoinstConfig.scheme == "device"
        end
        if AutoinstConfig.scheme == "label"
          Report.Error(_("label not found while looking for autoyast profile"))
        end
      end
      filename = basename(AutoinstConfig.filepath)


      if filename != ""
        Builtins.y2milestone("File=%1", filename)
        Builtins.y2milestone(
          "Get %1://%2/%3 to %4",
          AutoinstConfig.scheme,
          AutoinstConfig.host,
          AutoinstConfig.filepath,
          localfile
        )
        ret = Get(
          AutoinstConfig.scheme,
          AutoinstConfig.host,
          AutoinstConfig.filepath,
          localfile
        )
        if !ret
          # autoyast hit an error while fetching it's config file
          error = _("An error occurred while fetching the profile:\n")
          Report.Error(Ops.add(error, @GET_error))
          return false
        end
        tmp = Convert.to_string(SCR.Read(path(".target.string"), localfile))
        l = Builtins.splitstring(tmp, "\n")
        while tmp != nil && Ops.get(l, 0, "") == "-----BEGIN PGP MESSAGE-----"
          Builtins.y2milestone("encrypted profile found")
          UI.OpenDialog(
            VBox(
              Label(
                _("Encrypted AutoYaST profile. Enter the correct password.")
              ),
              Password(Id(:password), ""),
              PushButton(Id(:ok), _("&OK"))
            )
          )
          p = ""
          button = nil
          begin
            button = UI.UserInput
            p = Convert.to_string(UI.QueryWidget(Id(:password), :Value))
          end until button == :ok
          UI.CloseDialog
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat(
              "gpg2 --batch --output \"/tmp/decrypt.xml\" --passphrase \"%1\" %2",
              AutoinstConfig.ShellEscape(p),
              localfile
            )
          )
          if Ops.greater_than(
              SCR.Read(path(".target.size"), "/tmp/decrypt.xml"),
              0
            )
            SCR.Execute(
              path(".target.bash"),
              Builtins.sformat("mv /tmp/decrypt.xml %1", localfile)
            )
            Builtins.y2milestone(
              "decrypted. Moving now /tmp/decrypt.xml to %1",
              localfile
            )
            tmp = Convert.to_string(SCR.Read(path(".target.string"), localfile))
            l = Builtins.splitstring(tmp, "\n")
          end
        end
      else
        is_directory = true
      end

      AutoinstConfig.directory = dirname(AutoinstConfig.filepath)

      Builtins.y2milestone("Dir=%1", AutoinstConfig.directory)
      Builtins.y2milestone("Fetching Rules File")

      # Get rules file

      mkdir = Convert.to_boolean(
        SCR.Execute(path(".target.mkdir"), AutoinstConfig.local_rules_location)
      )
      if !mkdir
        Builtins.y2error(
          "Error creating directory: %1",
          AutoinstConfig.local_rules_location
        )
      end

      if is_directory
        ret = Get(
          AutoinstConfig.scheme,
          AutoinstConfig.host,
          Ops.add(
            Ops.add(AutoinstConfig.directory, "/"),
            AutoinstConfig.remote_rules_location
          ),
          AutoinstConfig.local_rules_file
        )
      else
        ret = false
      end

      if ret
        AutoInstallRules.userrules = true
      else
        AutoInstallRules.userrules = false
        SCR.Execute(path(".target.remove"), AutoinstConfig.local_rules_file)
      end

      process_rules = true
      try_default_rules = false
      if AutoInstallRules.userrules
        Builtins.y2milestone("Reading Rules File")
        AutoInstallRules.Read
        # returns false if no rules have matched
        ret = AutoInstallRules.GetRules
        try_default_rules = true if !ret
      else
        # required for classes too. Without it, they only work with rules together
        try_default_rules = true
      end

      # Hex IP, MAC Address.
      if try_default_rules
        Builtins.y2milestone("Creating default Rules")
        if is_directory
          # Create rules for hex ip and mac address
          AutoInstallRules.CreateDefault
        else
          # Create rules for file
          AutoInstallRules.CreateFile(filename)
        end
        ret = AutoInstallRules.GetRules
        return false if !ret
      end

      if process_rules
        rulesret = AutoInstallRules.Process(AutoinstConfig.xml_tmpfile)
        Builtins.y2milestone("rulesret=%1", rulesret)
        return rulesret
      end

      true
    end

    publish :function => :ProfileLocation, :type => "void ()"
    publish :function => :Process, :type => "boolean ()"
  end

  ProfileLocation = ProfileLocationClass.new
  ProfileLocation.main
end
