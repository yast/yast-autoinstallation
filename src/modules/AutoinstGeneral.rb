# encoding: utf-8

# File:	modules/AutoinstGeneral.ycp
# Package:	Autoyast
# Summary:	Configuration of general settings for autoyast
# Authors:	Anas Nashif (nashif@suse.de)
#
# $Id$
require "yast"

module Yast
  class AutoinstGeneralClass < Module
    include Yast::Logger

    def main
      Yast.import "Pkg"
      textdomain "autoinst"

      Yast.import "Stage"
      Yast.import "AutoInstall"
      Yast.import "AutoinstConfig"
      Yast.import "Summary"
      Yast.import "Keyboard"
      Yast.import "Language"
      Yast.import "Timezone"
      Yast.import "Misc"
      Yast.import "Profile"
      Yast.import "ProductFeatures"
      Yast.import "Storage"
      Yast.import "SignatureCheckCallbacks"
      Yast.import "Report"
      Yast.import "Arch"

      # All shared data are in yast2.rpm to break cyclic dependencies
      Yast.import "AutoinstData"

      #
      # Show proposal and ask user for confirmation to go on with auto-installation
      # Similar to interactive mode, without letting use change settings
      # Interactive mode implies confirmation as well..
      #
      @Confirm = true

      # Running autoyast second_stage
      @second_stage = true

      #
      # Mode Settings
      #
      @mode = {}

      @signature_handling = {}

      @askList = []

      #    global list<string> proposals = ["bootloader_proposal", "software_proposal", "country_simple_proposal", "timezone_proposal", "users_proposal", "runlevel_proposal", "hwinfo_proposal", "deploying_proposal"];
      @proposals = []

      @storage = {}

      # S390
      @cio_ignore = true

      # default value of settings modified
      @modified = false
      AutoinstGeneral()
    end

    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      @modified = true

      nil
    end

    # Functions which returns if the settings were modified
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end

    # Summary of configuration
    # @return [String] Formatted summary
    def Summary
      #string language_name		= "";
      #string keyboard_name		= "";


      summary = ""

      summary = Summary.AddHeader(summary, _("Confirm installation?"))
      summary = Summary.AddLine(
        summary,
        Ops.get_boolean(@mode, "confirm", true) ? _("Yes") : _("No")
      )

      summary = Summary.AddHeader(summary, _("Second Stage of AutoYaST"))
      summary = Summary.AddLine(
        summary,
        Ops.get_boolean(@mode, "second_stage", true) ? _("Yes") : _("No")
      )

      summary = Summary.AddHeader(
        summary,
        _("Halting the machine after stage one")
      )
      summary = Summary.AddLine(
        summary,
        Ops.get_boolean(@mode, "halt", false) ? _("Yes") : _("No")
      )
      if Ops.get_boolean(@mode, "final_halt", false) == true
        summary = Summary.AddHeader(
          summary,
          _("Halting the machine after stage two")
        )
        summary = Summary.AddLine(summary, _("Yes"))
      end
      if Ops.get_boolean(@mode, "final_reboot", false) == true
        summary = Summary.AddHeader(
          summary,
          _("Reboot the machine after stage two")
        )
        summary = Summary.AddLine(summary, _("Yes"))
      end


      summary = Summary.AddHeader(summary, _("Signature Handling"))
      summary = Summary.AddLine(
        summary,
        Ops.get_boolean(@signature_handling, "accept_unsigned_file", false) ?
          _("Accepting unsigned files") :
          _("Not accepting unsigned files")
      )
      summary = Summary.AddLine(
        summary,
        Ops.get_boolean(
          @signature_handling,
          "accept_file_without_checksum",
          false
        ) ?
          _("Accepting files without a checksum") :
          _("Not accepting files without a checksum")
      )
      summary = Summary.AddLine(
        summary,
        Ops.get_boolean(
          @signature_handling,
          "accept_verification_failed",
          false
        ) ?
          _("Accepting failed verifications") :
          _("Not accepting failed verifications")
      )
      summary = Summary.AddLine(
        summary,
        Ops.get_boolean(@signature_handling, "accept_unknown_gpg_key", false) ?
          _("Accepting unknown GPG keys") :
          _("Not accepting unknown GPG Keys")
      )
      summary = Summary.AddLine(
        summary,
        Ops.get_boolean(@signature_handling, "import_gpg_key", false) ?
          _("Importing new GPG keys") :
          _("Not importing new GPG Keys")
      )

      #	summary = Summary::AddHeader(summary, _("Proposals"));
      #        foreach(string p, proposals, ``{
      #		summary = Summary::AddLine(summary, p);
      #	});

      summary
    end

    # Import Configuration
    # @param [Hash] settings
    # @return booelan
    def Import(settings)
      settings = deep_copy(settings)
      SetModified()
      Builtins.y2milestone("General import: %1", settings)
      @mode = Ops.get_map(settings, "mode", {})
      @cio_ignore = Ops.get_boolean(settings, "cio_ignore", true)
      @signature_handling = Ops.get_map(settings, "signature-handling", {})
      @askList = Ops.get_list(settings, "ask-list", [])
      @proposals = Ops.get_list(settings, "proposals", [])
      @storage = Ops.get_map(settings, "storage", {})

      SetSignatureHandling()
      SetMultipathing()
      set_btrfs_default_subvolume_name

      true
    end


    # Export Configuration
    # @return [Hash]
    def Export
      general = {}

      Ops.set(general, "mode", @mode)
      Ops.set(general, "signature-handling", @signature_handling)
      Ops.set(general, "ask-list", @askList)
      Ops.set(general, "proposals", @proposals)

      btrfs_set_default_subvol = btrfs_default_subvol_to_profile
      unless btrfs_set_default_subvol.nil?
        Ops.set(@storage, "btrfs_set_default_subvolume_name", btrfs_set_default_subvol)
      end
      Ops.set(general, "storage", @storage)

      if Yast::Arch.s390
        if Yast::Mode.installation
          # Taking the selected value (selected by user or AutoYaST)
          general["cio_ignore"] = @cio_ignore
        else
          # Trying to evalute the state from the installed system.
          # Disabled if there are no active devices defined. (Call
          # "cio_ignore -L", stored in /boot/zipl/active_devices.txt)
          active_device_file = File.join(Yast::Installation.destdir,
            "/boot/zipl/active_devices.txt")
          general["cio_ignore"] = File.exist?(active_device_file) &&
            File.stat(active_device_file).size > 0
        end
      end

      deep_copy(general)
    end

    # set the sigature handling
    # @return [void]
    def SetSignatureHandling
      # this will break compatibility a bit. A XML file without signature handling can
      # block the installation now because we have the popups back
      Pkg.CallbackAcceptUnsignedFile(
        fun_ref(
          SignatureCheckCallbacks.method(:AcceptUnsignedFile),
          "boolean (string, integer)"
        )
      )
      Pkg.CallbackAcceptFileWithoutChecksum(
        fun_ref(
          SignatureCheckCallbacks.method(:AcceptFileWithoutChecksum),
          "boolean (string)"
        )
      )
      Pkg.CallbackAcceptVerificationFailed(
        fun_ref(
          SignatureCheckCallbacks.method(:AcceptVerificationFailed),
          "boolean (string, map <string, any>, integer)"
        )
      )
      Pkg.CallbackTrustedKeyAdded(
        fun_ref(
          SignatureCheckCallbacks.method(:TrustedKeyAdded),
          "void (map <string, any>)"
        )
      )
      Pkg.CallbackAcceptUnknownGpgKey(
        fun_ref(
          SignatureCheckCallbacks.method(:AcceptUnknownGpgKey),
          "boolean (string, string, integer)"
        )
      )
      Pkg.CallbackImportGpgKey(
        fun_ref(
          SignatureCheckCallbacks.method(:ImportGpgKey),
          "boolean (map <string, any>, integer)"
        )
      )
      Pkg.CallbackAcceptWrongDigest(
        fun_ref(
          SignatureCheckCallbacks.method(:AcceptWrongDigest),
          "boolean (string, string, string)"
        )
      )
      Pkg.CallbackAcceptUnknownDigest(
        fun_ref(
          SignatureCheckCallbacks.method(:AcceptUnknownDigest),
          "boolean (string, string)"
        )
      )
      Pkg.CallbackTrustedKeyRemoved(
        fun_ref(
          SignatureCheckCallbacks.method(:TrustedKeyRemoved),
          "void (map <string, any>)"
        )
      )

      Pkg.CallbackPkgGpgCheck(
        fun_ref(AutoInstall.method(:pkg_gpg_check),
        "string (map)"
      ))

      if Builtins.haskey(@signature_handling, "accept_unsigned_file")
        Pkg.CallbackAcceptUnsignedFile(
          Ops.get_boolean(@signature_handling, "accept_unsigned_file", false) ?
            fun_ref(
              AutoInstall.method(:callbackTrue_boolean_string_integer),
              "boolean (string, integer)"
            ) :
            fun_ref(
              AutoInstall.method(:callbackFalse_boolean_string_integer),
              "boolean (string, integer)"
            )
        )
      end
      if Builtins.haskey(@signature_handling, "accept_file_without_checksum")
        Pkg.CallbackAcceptFileWithoutChecksum(
          Ops.get_boolean(
            @signature_handling,
            "accept_file_without_checksum",
            false
          ) ?
            fun_ref(
              AutoInstall.method(:callbackTrue_boolean_string),
              "boolean (string)"
            ) :
            fun_ref(
              AutoInstall.method(:callbackFalse_boolean_string),
              "boolean (string)"
            )
        )
      end
      if Builtins.haskey(@signature_handling, "accept_verification_failed")
        Pkg.CallbackAcceptVerificationFailed(
          Ops.get_boolean(
            @signature_handling,
            "accept_verification_failed",
            false
          ) ?
            fun_ref(
              AutoInstall.method(:callbackTrue_boolean_string_map_integer),
              "boolean (string, map <string, any>, integer)"
            ) :
            fun_ref(
              AutoInstall.method(:callbackFalse_boolean_string_map_integer),
              "boolean (string, map <string, any>, integer)"
            )
        )
      end
      if Builtins.haskey(@signature_handling, "trusted_key_added")
        Pkg.CallbackTrustedKeyAdded(
          fun_ref(
            AutoInstall.method(:callback_void_map),
            "void (map <string, any>)"
          )
        )
      end
      if Builtins.haskey(@signature_handling, "trusted_key_removed")
        Pkg.CallbackTrustedKeyRemoved(
          fun_ref(
            AutoInstall.method(:callback_void_map),
            "void (map <string, any>)"
          )
        )
      end
      if Builtins.haskey(@signature_handling, "accept_unknown_gpg_key")
        Pkg.CallbackAcceptUnknownGpgKey(
          Ops.get_boolean(@signature_handling, "accept_unknown_gpg_key", false) ?
            fun_ref(
              AutoInstall.method(:callbackTrue_boolean_string_string_integer),
              "boolean (string, string, integer)"
            ) :
            fun_ref(
              AutoInstall.method(:callbackFalse_boolean_string_string_integer),
              "boolean (string, string, integer)"
            )
        )
      end
      if Builtins.haskey(@signature_handling, "import_gpg_key")
        Pkg.CallbackImportGpgKey(
          Ops.get_boolean(@signature_handling, "import_gpg_key", false) ?
            fun_ref(
              AutoInstall.method(:callbackTrue_boolean_map_integer),
              "boolean (map <string, any>, integer)"
            ) :
            fun_ref(
              AutoInstall.method(:callbackFalse_boolean_map_integer),
              "boolean (map <string, any>, integer)"
            )
        )
      end
      if Builtins.haskey(@signature_handling, "accept_wrong_digest")
        Pkg.CallbackAcceptWrongDigest(
          Ops.get_boolean(@signature_handling, "accept_wrong_digest", false) ?
            fun_ref(
              AutoInstall.method(:callbackTrue_boolean_string_string_string),
              "boolean (string, string, string)"
            ) :
            fun_ref(
              AutoInstall.method(:callbackFalse_boolean_string_string_string),
              "boolean (string, string, string)"
            )
        )
      end
      if Builtins.haskey(@signature_handling, "accept_unknown_digest")
        Pkg.CallbackAcceptWrongDigest(
          Ops.get_boolean(@signature_handling, "accept_unknown_digest", false) ?
            fun_ref(
              AutoInstall.method(:callbackTrue_boolean_string_string_string),
              "boolean (string, string, string)"
            ) :
            fun_ref(
              AutoInstall.method(:callbackFalse_boolean_string_string_string),
              "boolean (string, string, string)"
            )
        )
      end

      nil
    end

    # set multipathing
    # @return [void]
    def SetMultipathing
      val = @storage.fetch("start_multipath",false)
      Builtins.y2milestone("SetMultipathing val:%1", val)
      Storage.SetMultipathStartup(val)
    end

    # Set Btrfs default subvolume name
    #
    # Check "general/storage/btrfs_set_default_subvolume_name" in the profile.
    # It does nothing if that element does not exist.
    #
    # @return ["@","",nil] Default subvolume name to use.
    #
    # @see FileSystems.default_subvol
    def set_btrfs_default_subvolume_name
      return unless @storage.has_key?("btrfs_set_default_subvolume_name")
      value = @storage["btrfs_set_default_subvolume_name"] ? "@" : ""
      log.info "Setting default subvolume to: '#{value}'"
      FileSystems.default_subvol = value
    end

    # NTP syncing
    def NtpSync
      ntp_server = @mode["ntp_sync_time_before_installation"]
      if ntp_server
        Builtins.y2milestone("NTP syncing with #{ntp_server}")
        Popup.ShowFeedback(
          _("Syncing time..."),
          # TRANSLATORS: %s is the name of the ntp server
          _("Syncing time with %s.") % ntp_server
        )
        ret = SCR.Execute(path(".target.bash"), "/usr/sbin/ntpdate -b #{ntp_server}")
        if ret > 0
          Report.Error(_("Time syncing failed."))
        else
          ret = SCR.Execute(path(".target.bash"), "/sbin/hwclock --systohc")
          if ret > 0
            Report.Error(_("Cannot update system time."))
          end
        end
        Popup.ClearFeedback
      end
    end

    # Set the "kexec_reboot" flag in the product
    # description in order to force a reboot with
    # kexec at the end of the first installation
    # stage.
    # @return [void]
    def SetRebootAfterFirstStage
      if Builtins.haskey(@mode, "forceboot")
        ProductFeatures.SetBooleanFeature(
          "globals",
          "kexec_reboot",
          !Ops.get_boolean(@mode, "forceboot", false)
        )
      end
    end

    # Write General  Configuration
    # @return [Boolean] true on success
    def Write
      AutoinstConfig.Confirm = Ops.get_boolean(@mode, "confirm", true)
      AutoinstConfig.cio_ignore = @cio_ignore
      AutoinstConfig.second_stage = @mode["second_stage"] if @mode.has_key?("second_stage")
      SetRebootAfterFirstStage()
      AutoinstConfig.Halt = Ops.get_boolean(@mode, "halt", false)
      AutoinstConfig.RebootMsg = Ops.get_boolean(@mode, "rebootmsg", false)
      AutoinstConfig.setProposalList(@proposals)

      # see bug #597723. Some machines can't boot with the new alignment that parted uses
      # `align_cylinder == old behavior
      # `align_optimal  == new behavior
      if @storage.has_key?("partition_alignment")
        val = @storage.fetch("partition_alignment",:align_optimal)
        Storage.SetPartitionAlignment(val)
        Builtins.y2milestone( "alignment set to %1", val )
      end

      SetMultipathing()

      SetSignatureHandling()

      NtpSync()

      nil
    end

    # Constructor
    def AutoinstGeneral
      if Stage.cont
        # FIXME: wrong position for this
        if Ops.get_map(Profile.current, "general", {}) != {}
          Import(Ops.get_map(Profile.current, "general", {}))
        end
        SetSignatureHandling()
      end
      nil
    end

  protected

    # Return the value to use as 'btrfs_set_default_subvolume_name' in the profile
    #
    # In case it matches the product's default, it should not be exported.
    #
    # @return [Boolean,nil] Value to use (true or false). If nil, no value
    #                       should be exported.
    def btrfs_default_subvol_to_profile
      if FileSystems.default_subvol != FileSystems.default_subvol_from_product
        return FileSystems.default_subvol == "" ? false : true
      end
      nil
    end


    publish :variable => :Confirm, :type => "boolean"
    publish :variable => :second_stage, :type => "boolean"
    publish :variable => :mode, :type => "map"
    publish :variable => :signature_handling, :type => "map"
    publish :variable => :askList, :type => "list"
    publish :variable => :proposals, :type => "list <string>"
    publish :variable => :modified, :type => "boolean"
    publish :function => :SetModified, :type => "void ()"
    publish :function => :GetModified, :type => "boolean ()"
    publish :function => :Summary, :type => "string ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Export, :type => "map ()"
    publish :function => :SetSignatureHandling, :type => "void ()"
    publish :function => :SetMultipathing, :type => "void ()"
    publish :function => :SetRebootAfterFirstStage, :type => "void ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :AutoinstGeneral, :type => "void ()"

  end

  AutoinstGeneral = AutoinstGeneralClass.new
  AutoinstGeneral.main
end
