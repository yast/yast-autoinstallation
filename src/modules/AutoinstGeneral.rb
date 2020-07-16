# File:  modules/AutoinstGeneral.ycp
# Package:  Autoyast
# Summary:  Configuration of general settings for autoyast
# Authors:  Anas Nashif (nashif@suse.de)
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
      Yast.import "AutoinstStorage"
      Yast.import "Summary"
      Yast.import "Keyboard"
      Yast.import "Language"
      Yast.import "Timezone"
      Yast.import "Misc"
      Yast.import "NtpClient"
      Yast.import "Profile"
      Yast.import "ProductFeatures"

      Yast.import "SignatureCheckCallbacks"
      Yast.import "Report"
      Yast.import "Arch"

      # All shared data are in yast2.rpm to break cyclic dependencies
      Yast.import "AutoinstData"

      # Running autoyast second_stage
      @second_stage = true

      #
      # Mode Settings
      #
      @mode = {}

      @signature_handling = {}

      @askList = []

      @proposals = []

      @storage = {}

      # S390
      @cio_ignore = true

      @self_update = true
      @minimal_configuration = false

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
      # string language_name    = "";
      # string keyboard_name    = "";

      summary = ""

      summary = Summary.AddHeader(summary, _("Confirm installation?"))
      summary = Summary.AddLine(
        summary,
        mode.fetch("confirm", true) ? _("Yes") : _("No")
      )

      summary = Summary.AddHeader(summary, _("Second Stage of AutoYaST"))
      summary = Summary.AddLine(
        summary,
        mode.fetch("second_stage", true) ? _("Yes") : _("No")
      )

      summary = Summary.AddHeader(
        summary,
        _("Halting the machine after stage one")
      )
      summary = Summary.AddLine(
        summary,
        mode["halt"] ? _("Yes") : _("No")
      )
      if mode["final_halt"]
        summary = Summary.AddHeader(
          summary,
          _("Halting the machine after stage two")
        )
        summary = Summary.AddLine(summary, _("Yes"))
      end
      if mode["final_reboot"]
        summary = Summary.AddHeader(
          summary,
          _("Reboot the machine after stage two")
        )
        summary = Summary.AddLine(summary, _("Yes"))
      end

      summary = Summary.AddHeader(summary, _("Signature Handling"))
      summary = Summary.AddLine(
        summary,
        if signature_handling["accept_unsigned_file"]
          _("Accepting unsigned files")
        else
          _("Not accepting unsigned files")
        end
      )
      summary = Summary.AddLine(
        summary,
        if signature_handling["accept_file_without_checksum"]
          _("Accepting files without a checksum")
        else
          _("Not accepting files without a checksum")
        end
      )
      summary = Summary.AddLine(
        summary,
        if signature_handling["accept_verification_failed"]
          _("Accepting failed verifications")
        else
          _("Not accepting failed verifications")
        end
      )
      summary = Summary.AddLine(
        summary,
        if signature_handling["accept_unknown_gpg_key"]
          _("Accepting unknown GPG keys")
        else
          _("Not accepting unknown GPG Keys")
        end
      )
      summary = Summary.AddLine(
        summary,
        if signature_handling["import_gpg_key"]
          _("Importing new GPG keys")
        else
          _("Not importing new GPG Keys")
        end
      )

      summary
    end

    # Import Configuration
    # @param [Hash] settings
    # @return booelan
    def Import(settings)
      settings = deep_copy(settings)
      SetModified()
      log.info "General import: #{settings.inspect}"
      @mode = settings.fetch("mode", {})
      @cio_ignore = settings.fetch("cio_ignore", true)
      @signature_handling = settings.fetch("signature-handling", {})
      @askList = settings.fetch("ask-list", [])
      @proposals = settings.fetch("proposals", [])
      AutoinstStorage.import_general_settings(settings["storage"])
      @minimal_configuration = settings.fetch("minimal_configuration", false)
      @self_update = settings["self_update"] # no default as we want to know if it is explicit
      @self_update_url = settings["self_update_url"]
      @wait = settings.fetch("wait", {})

      SetSignatureHandling()

      true
    end

    # Export Configuration
    # @return [Hash]
    def Export
      general = {
        "mode"               => mode,
        "signature-handling" => signature_handling,
        "ask-list"           => askList,
        "proposals"          => proposals,
        "storage"            => AutoinstStorage.export_general_settings
      }

      if Yast::Arch.s390
        if Yast::Mode.installation
          # Taking the selected value (selected by user or AutoYaST)
          general["cio_ignore"] = cio_ignore
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
          "string (map)")
      )

      if signature_handling.key?("accept_unsigned_file")
        Pkg.CallbackAcceptUnsignedFile(
          if signature_handling["accept_unsigned_file"]
            fun_ref(
              AutoInstall.method(:callbackTrue_boolean_string_integer),
              "boolean (string, integer)"
            )
          else
            fun_ref(
              AutoInstall.method(:callbackFalse_boolean_string_integer),
              "boolean (string, integer)"
            )
          end
        )
      end

      if signature_handling.key?("accept_file_without_checksum")
        Pkg.CallbackAcceptFileWithoutChecksum(
          if signature_handling["accept_file_without_checksum"]
            fun_ref(
              AutoInstall.method(:callbackTrue_boolean_string),
              "boolean (string)"
            )
          else
            fun_ref(
              AutoInstall.method(:callbackFalse_boolean_string),
              "boolean (string)"
            )
          end
        )
      end
      if signature_handling.key?("accept_verification_failed")
        Pkg.CallbackAcceptVerificationFailed(
          if signature_handling["accept_verification_failed"]
            fun_ref(
              AutoInstall.method(:callbackTrue_boolean_string_map_integer),
              "boolean (string, map <string, any>, integer)"
            )
          else
            fun_ref(
              AutoInstall.method(:callbackFalse_boolean_string_map_integer),
              "boolean (string, map <string, any>, integer)"
            )
          end
        )
      end
      if signature_handling.key?("trusted_key_added")
        Pkg.CallbackTrustedKeyAdded(
          fun_ref(
            AutoInstall.method(:callback_void_map),
            "void (map <string, any>)"
          )
        )
      end
      if signature_handling.key?("trusted_key_removed")
        Pkg.CallbackTrustedKeyRemoved(
          fun_ref(
            AutoInstall.method(:callback_void_map),
            "void (map <string, any>)"
          )
        )
      end
      if signature_handling.key?("accept_unknown_gpg_key")
        Pkg.CallbackAcceptUnknownGpgKey(
          if signature_handling["accept_unknown_gpg_key"]
            fun_ref(
              AutoInstall.method(:callbackTrue_boolean_string_string_integer),
              "boolean (string, string, integer)"
            )
          else
            fun_ref(
              AutoInstall.method(:callbackFalse_boolean_string_string_integer),
              "boolean (string, string, integer)"
            )
          end
        )
      end
      if signature_handling.key?("import_gpg_key")
        Pkg.CallbackImportGpgKey(
          if signature_handling["import_gpg_key"]
            fun_ref(
              AutoInstall.method(:callbackTrue_boolean_map_integer),
              "boolean (map <string, any>, integer)"
            )
          else
            fun_ref(
              AutoInstall.method(:callbackFalse_boolean_map_integer),
              "boolean (map <string, any>, integer)"
            )
          end
        )
      end
      if signature_handling.key?("accept_wrong_digest")
        Pkg.CallbackAcceptWrongDigest(
          if signature_handling["accept_wrong_digest"]
            fun_ref(
              AutoInstall.method(:callbackTrue_boolean_string_string_string),
              "boolean (string, string, string)"
            )
          else
            fun_ref(
              AutoInstall.method(:callbackFalse_boolean_string_string_string),
              "boolean (string, string, string)"
            )
          end
        )
      end
      if signature_handling.key?("accept_unknown_digest")
        Pkg.CallbackAcceptUnknownDigest(
          if signature_handling["accept_unknown_digest"]
            fun_ref(
              AutoInstall.method(:callbackTrue_boolean_string_string_string),
              "boolean (string, string, string)"
            )
          else
            fun_ref(
              AutoInstall.method(:callbackFalse_boolean_string_string_string),
              "boolean (string, string, string)"
            )
          end
        )
      end

      nil
    end

    # NTP syncing
    def NtpSync
      ntp_server = mode["ntp_sync_time_before_installation"]
      if ntp_server
        log.info "NTP syncing with #{ntp_server}"
        Popup.ShowFeedback(
          _("Syncing time..."),
          # TRANSLATORS: %s is the name of the ntp server
          _("Syncing time with %s.") % ntp_server
        )
        ret = NtpClient.sync_once(ntp_server)
        if ret > 0
          Report.Error(_("Time syncing failed."))
        else
          ret = SCR.Execute(path(".target.bash"), "/sbin/hwclock --systohc")
          Report.Error(_("Cannot update system time.")) if ret > 0
        end
        Popup.ClearFeedback
      end
    end

    # Write General  Configuration
    # @return [Boolean] true on success
    def Write
      AutoinstConfig.Confirm = mode.fetch("confirm", true)
      AutoinstConfig.cio_ignore = cio_ignore
      AutoinstConfig.second_stage = mode["second_stage"] if mode.key?("second_stage")
      SetRebootAfterFirstStage()
      AutoinstConfig.Halt = !!mode["halt"]
      AutoinstConfig.RebootMsg = !!mode["rebootmsg"]
      AutoinstConfig.setProposalList(proposals)

      if @storage["partition_alignment"] == :align_cylinder
        # This option has been set by the user manually in the AY configuration file
        # (Not via clone_system)
        # It is not supported anymore with storage-ng. So the user should remove
        # this option.
        Popup.Warning(_("The AutoYaST option <partition_alignment> is not supported anymore."))
      end

      SetSignatureHandling()

      NtpSync()

      nil
    end

    # Constructor
    def AutoinstGeneral
      return unless Stage.cont

      # FIXME: wrong place for this
      general_settings = Profile.current.fetch("general", {})
      Import(general_settings) unless general_settings.empty?

      nil
    end

    # Set the "kexec_reboot" flag in the product
    # description in order to force a reboot with
    # kexec at the end of the first installation
    # stage.
    # @return [void]
    def SetRebootAfterFirstStage
      return unless mode.key?("forceboot")

      ProductFeatures.SetBooleanFeature(
        "globals",
        "kexec_reboot",
        !mode["forceboot"]
      )
    end

    # Gets if minimal configuration option is set to true.
    # @return [true,false] returns false if not defined in profile
    def minimal_configuration?
      @minimal_configuration
    end

    # returns if self update is explcitelly enabled
    # @return [true,false,nil] returns specified value or nil if not defined
    attr_reader :self_update

    # returns self update url
    # @return [String,nil] returns url to self update or nil if not defined
    attr_reader :self_update_url

    # list of processes for which wait in given stage
    # @return [Array<Hash>] list of processes definition.
    # @see https://doc.opensuse.org/projects/autoyast/#CreateProfile-General-wait for hash keys
    def processes_to_wait(stage)
      @wait[stage] || []
    end

    publish variable: :second_stage, type: "boolean"
    publish variable: :mode, type: "map"
    publish variable: :signature_handling, type: "map"
    publish variable: :askList, type: "list"
    publish variable: :proposals, type: "list <string>"
    publish variable: :modified, type: "boolean"
    publish function: :SetModified, type: "void ()"
    publish function: :GetModified, type: "boolean ()"
    publish function: :Summary, type: "string ()"
    publish function: :Import, type: "boolean (map)"
    publish function: :Export, type: "map ()"
    publish function: :SetSignatureHandling, type: "void ()"
    publish function: :SetRebootAfterFirstStage, type: "void ()"
    publish function: :Write, type: "boolean ()"
    publish function: :AutoinstGeneral, type: "void ()"

  private

    attr_reader :cio_ignore
  end

  AutoinstGeneral = AutoinstGeneralClass.new
  AutoinstGeneral.main
end
