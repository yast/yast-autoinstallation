# File:  modules/ProfileLocation.ycp
# Package:  Auto-installation
# Summary:  Process Auto-Installation Location
# Author:  Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"

require "autoinstall/xml_checks"
require "y2storage"

module Yast
  class ProfileLocationClass < Module
    include Yast::Logger

    def main
      Yast.import "UI"
      textdomain "autoinst"

      Yast.import "AutoinstConfig"
      Yast.import "AutoInstallRules"
      Yast.import "Mode"
      Yast.import "Installation"
      Yast.import "Report"
      Yast.import "Label"
      Yast.import "URL"
      Yast.import "InstURL"

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
      Builtins.y2milestone(
        "Path to remote control file: %1",
        AutoinstConfig.filepath
      )

      # Due to self-update this process could be called twice.
      # So we have to initialize the stack again. (bnc#1051483)
      AutoInstallRules.reset

      localfile = AutoinstConfig.xml_tmpfile

      is_directory = false

      if AutoinstConfig.scheme == "relurl"
        url_str = InstURL.installInf2Url("")
        log.info("installation path from install.inf: #{url_str}")

        if !url_str.empty?
          url = URL.Parse(url_str)
          AutoinstConfig.scheme = url["scheme"]
          AutoinstConfig.host = url["host"]
          AutoinstConfig.filepath = File.join(url["path"], AutoinstConfig.filepath)

          AutoinstConfig.scheme = "file" if ["cd", "cdrom"].include? AutoinstConfig.scheme

          ayrelurl = "#{AutoinstConfig.scheme}://#{AutoinstConfig.host}/#{AutoinstConfig.filepath}"
          log.info("relurl for profile changed to: #{ayrelurl}")
          SCR.Write(path(".etc.install_inf.ayrelurl"), ayrelurl)
          SCR.Write(path(".etc.install_inf"), nil)
        else
          log.warn("Cannot evaluate ZyppRepoURL from /etc/install.inf")
        end
      elsif AutoinstConfig.scheme == "label"
        # autoyast=label://my_home//autoinst.xml in linuxrc:
        # AY is searching for a partition with the label "my_home". This partition
        # will be mounted and the autoinst.xml will be used for installation.
        log.info("searching label #{AutoinstConfig.host}")
        fs = Y2Storage::StorageManager.instance.probed.filesystems.find do |f|
          f.label == AutoinstConfig.host
        end
        if fs&.blk_devices&.first
          AutoinstConfig.scheme = "device"
          AutoinstConfig.host = fs.blk_devices.first.basename
          log.info("found on #{AutoinstConfig.host}")
        else
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
        while !tmp.nil? && Ops.get(l, 0, "") == "-----BEGIN PGP MESSAGE-----"
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
          next unless Ops.greater_than(
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

      ret = if is_directory
        Get(
          AutoinstConfig.scheme,
          AutoinstConfig.host,
          Ops.add(
            Ops.add(AutoinstConfig.directory, "/"),
            AutoinstConfig.remote_rules_location
          ),
          AutoinstConfig.local_rules_file
        )
      else
        false
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
        # display an error when the rules file is not valid and return false
        return false unless Y2Autoinstallation::XmlChecks.valid_rules?

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
        # validate the profile
        return false if rulesret && !Y2Autoinstallation::XmlChecks.valid_profile?

        Builtins.y2milestone("rulesret=%1", rulesret)
        return rulesret
      end

      true
    end

    publish function: :ProfileLocation, type: "void ()"
    publish function: :Process, type: "boolean ()"
  end

  ProfileLocation = ProfileLocationClass.new
  ProfileLocation.main
end
