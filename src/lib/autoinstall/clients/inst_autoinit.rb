require "autoinstall/autosetup_helpers"
require "autoinstall/xml_checks"
require "y2packager/medium_type"

Yast.import "AutoInstall"
Yast.import "AutoInstallRules"
Yast.import "AutoinstConfig"
Yast.import "AutoinstFunctions"
Yast.import "AutoinstGeneral"
Yast.import "Call"
Yast.import "Console"
Yast.import "InstURL"
Yast.import "Installation"
Yast.import "Linuxrc"
Yast.import "Mode"
Yast.import "Popup"
Yast.import "Profile"
Yast.import "ProfileLocation"
Yast.import "Progress"
Yast.import "Report"
Yast.import "UI"
Yast.import "URL"
Yast.import "Y2ModuleConfig"

module Y2Autoinstallation
  module Clients
    class InstAutoinit
      include Y2Autoinstallation::AutosetupHelpers
      include Yast::Logger
      include Yast::UIShortcuts
      include Yast::I18n
      extend Yast::I18n

      def self.run
        new.run
      end

      def initialize
        textdomain "autoinst"
      end

      def run
        Yast::Console.Init

        help_text = _(
          "<p>\nPlease wait while the system is prepared for autoinstallation.</p>\n"
        )
        progress_stages = [
          _("Probe hardware"),
          _("Retrieve & Read Control File"),
          _("Parse control file"),
          _("Initial Configuration")
        ]

        Yast::Progress.New(
          _("Preparing System for Automatic Installation"),
          "", # progress_title
          6, # progress bar length
          progress_stages,
          [],
          help_text
        )
        Yast::Progress.NextStage
        Yast::Progress.Title(_("Preprobing stage"))
        log.info "pre probing"

        Yast::WFM.CallFunction("inst_iscsi-client", []) if Yast::Linuxrc.useiscsi

        Yast::Progress.NextStep
        Yast::Progress.Title(_("Probing hardware..."))
        log.info "Probing hardware..."

        autoupgrade_profile

        ret = processProfile
        return ret if ret != :ok

        Yast::Progress.Finish

        # when installing from the online installation medium we need to
        # register the system earlier because the medium does not contain any
        # repositories, we need the repositories from the registration server
        if Y2Packager::MediumType.online? && !Yast::Mode.autoupgrade
          autosetup_network if network_before_proposal?

          res = register_system
          return res if res
        # offline registration need here to init software management according to picked product
        # or autoupgrade without scc
        elsif Y2Packager::MediumType.offline?
          res = offline_product
          return res if res
        end

        if !(Yast::Mode.autoupgrade && Yast::AutoinstConfig.ProfileInRootPart)
          @ret = Yast::WFM.CallFunction("inst_system_analysis", [])
          return @ret if @ret == :abort
        end

        if Yast::Profile.current["iscsi-client"]
          log.info "iscsi-client found"
          Yast::WFM.CallFunction(
            "iscsi-client_auto",
            ["Import", Yast::Profile.current["iscsi-client"]]
          )
          Yast::WFM.CallFunction("iscsi-client_auto", ["Write"])
        end

        if Yast::Profile.current["fcoe-client"]
          log.info "fcoe-client found"
          Yast::WFM.CallFunction(
            "fcoe-client_auto",
            ["Import", Yast::Profile.current["fcoe-client"]]
          )
          Yast::WFM.CallFunction("fcoe-client_auto", ["Write"])
        end

        if !(Y2Packager::MediumType.offline? || Yast::AutoinstFunctions.selected_product ||
            Yast::Mode.autoupgrade)
          msg = _("None or wrong base product has been defined " \
           "in the AutoYaST configuration file. " \
           "Please check the <b>products</b> entry in the <b>software</b> section.<br><br>" \
           "Following base products are available:<br>")
          Yast::AutoinstFunctions.available_base_products.each do |product|
            msg += "#{product.name} (#{product.display_name})<br>"
          end
          Yast::Popup.LongError(msg) # No timeout because we are stopping the installation/upgrade.
          return :abort
        end

        return :abort if Yast::UI.PollInput == :abort && Yast::Popup.ConfirmAbort(:painless)

        :next
      end

    private

      # Checking profile for unsupported sections.
      def check_unsupported_profile_sections
        unsupported_sections = Yast::Y2ModuleConfig.unsupported_profile_sections
        if unsupported_sections.any?
          log.error "Could not process these unsupported profile " \
            "sections: #{unsupported_sections}"
          Yast::Report.LongWarning(
            # TRANSLATORS: Error message, %s is replaced by newline-separated
            # list of unsupported sections of the profile
            # Do not translate words in brackets
            _(
              "These sections of AutoYaST profile are not supported " \
              "anymore:<br><br>%s<br><br>" \
              "Please, use, e.g., &lt;scripts/&gt; or &lt;files/&gt;" \
              " to change the configuration."
            ) % unsupported_sections.map { |section| "&lt;#{section}/&gt;" }.join("<br>")
          )
        end
      end

      def processProfile
        Yast::Progress.NextStage
        log.info "Starting processProfile msg:#{Yast::AutoinstConfig.message}"
        Yast::Progress.Title(Yast::AutoinstConfig.message)
        Yast::Progress.NextStep
        loop do
          r = Yast::ProfileLocation.Process
          if r
            break
          else
            newURI = ProfileSourceDialog(Yast::AutoinstConfig.OriginalURI)
            if newURI == ""
              return :abort
            else
              # Updating new URI in /etc/install.inf (bnc#963487)
              # SCR.Write does not work in inst-sys here.
              Yast::WFM.Execute(
                Yast::Path.new(".local.bash"),
                "sed -i \'/AutoYaST:/c\AutoYaST: #{newURI}\' /etc/install.inf"
              )

              Yast::AutoinstConfig.ParseCmdLine(newURI)
              Yast::AutoinstConfig.SetProtocolMessage
              next
            end
          end
        end

        return :abort if Yast::UI.PollInput == :abort && Yast::Popup.ConfirmAbort(:painless)

        #
        # Set reporting behaviour to default, changed later if required
        #
        Yast::Report.LogMessages(true)
        Yast::Report.LogErrors(true)
        Yast::Report.LogWarnings(true)

        return :abort if Yast::UI.PollInput == :abort && Yast::Popup.ConfirmAbort(:painless)

        Yast::Progress.NextStage
        Yast::Progress.Title(_("Parsing control file"))

        # display an error when the profile is not valid and abort the installation
        return :abort unless Y2Autoinstallation::XmlChecks.valid_profile?

        log.info "Parsing control file"
        if !Yast::Profile.ReadXML(Yast::AutoinstConfig.xml_tmpfile) || Yast::Profile.current.nil?
          Yast::Popup.Error(
            _(
              "Error while parsing the control file.\n" \
                "Check the log files for more details or fix the\n" \
                "control file and try again.\n"
            )
          )
          return :abort
        end

        Yast::Builtins.y2debug("Autoinstall control file %1", Yast::Profile.current)

        # Checking profile for unsupported sections.
        check_unsupported_profile_sections

        Yast::Progress.NextStage
        Yast::Progress.Title(_("Initial Configuration"))
        log.info "Initial Configuration"
        Yast::Report.Import(Yast::Profile.current.fetch("report", {}))
        Yast::AutoinstGeneral.Import(Yast::Profile.current.fetch("general", {}))

        #
        # Copy the control file for easy access by user to  a pre-defined
        # directory
        #
        Yast::SCR.Execute(
          Yast::Path.new(".target.bash"),
          Yast::Builtins.sformat(
            "cp %1 %2/autoinst.xml",
            Yast::AutoinstConfig.xml_tmpfile,
            Yast::AutoinstConfig.profile_dir
          )
        )
        :ok
      end

      # Shows a dialog when 'control file' can't be found
      # @param [String] original Original value
      # @return [String] new value
      def ProfileSourceDialog(original)
        helptext = _(
          "<p>\n" \
            "A profile for this machine could not be found or retrieved.\n" \
            "Check that you entered the correct location\n" \
            "on the command line and try again. Because of this error, you\n" \
            "can only enter a URL to a profile and not to a directory. If you\n" \
            "are using rules or host name-based control files, restart the\n" \
            "installation process and make sure the control files are accessible.</p>\n"
        )
        title = _("System Profile Location")

        Yast::UI.OpenDialog(
          Opt(:decorated),
          HBox(
            HWeight(30, RichText(helptext)),
            HStretch(),
            HSpacing(1),
            HWeight(
              70,
              VBox(
                Heading(title),
                VSpacing(1),
                VStretch(),
                MinWidth(60,
                  Left(TextEntry(Id(:uri), _("&Profile Location:"), original))),
                VSpacing(1),
                VStretch(),
                HBox(
                  PushButton(Id(:retry), Opt(:default), Yast::Label.RetryButton),
                  PushButton(Id(:abort), Yast::Label.AbortButton)
                )
              )
            )
          )
        )

        uri = ""
        loop do
          ret = Yast::Convert.to_symbol(Yast::UI.UserInput)

          if ret == :abort && Yast::Popup.ConfirmAbort(:painless)
            break
          elsif ret == :retry
            uri = Yast::Convert.to_string(Yast::UI.QueryWidget(Id(:uri), :Value))
            if uri == ""
              next
            else
              break
            end
          end
        end

        Yast::UI.CloseDialog
        uri
      end

      # Sets on disk autoyast profile for autoupgrade if autoyast profile is not specified.
      def autoupgrade_profile
        return unless Yast::Mode.autoupgrade

        # if profile is defined, first read it, then probe hardware
        autoinstall = Yast::Linuxrc.InstallInf("AutoYaST")
        # feature that allows to have file on upgraded system at /root/autoupg.xml
        return if !autoinstall.nil? && !autoinstall.empty?

        Yast::AutoinstConfig.ParseCmdLine("file:///mnt/root/autoupg.xml")
        Yast::AutoinstConfig.ProfileInRootPart = true
      end

      # Register system acoording to profile
      # @return nil if all is fine or :abort if unrecoverable error found
      def register_system
        # check that the registration section is defined and registration is enabled
        reg_section = Yast::Profile.current.fetch(REGISTER_SECTION, {})
        reg_enabled = reg_section["do_registration"]

        if !reg_enabled
          msg = _("Registration is mandatory when using the online " \
            "installation medium. Enable registration in " \
            "the AutoYaST profile or use full installation medium.")
          Yast::Popup.LongError(msg) # No timeout because we are stopping the installation/upgrade.

          return :abort
        end

        suse_register

        nil
      end

      # sets product and initialize it for offline installation
      # @return nil if all is fine or :abort if unrecoverable error found
      def offline_product
        product = Yast::AutoinstFunctions.selected_product

        # if addons contain relurl. If so, then product have to defined, otherwise relurl
        # cannot be expanded in autoupgrade
        addon_profile = (Yast::Profile.current["add-on"] || {})
        addons = (addon_profile["add_on_products"] || []) + (addon_profile["add_on_others"] || [])
        addons_relurl = addons.find { |a| (a["relurl"] || "") =~ /relurl:\/\// }

        # duplicite code, but for offline medium we need to do it before system is initialized as
        # we get need product for initialize libzypp, but for others we need first init libzypp
        # to get available products.
        if product
          show_popup = true
          base_url = Yast::InstURL.installInf2Url("")
          log_url = Yast::URL.HidePassword(base_url)
          Yast::Packages.Initialize_StageInitial(show_popup, base_url, log_url, product.dir)
          # select the product to install
          Yast::Pkg.ResolvableInstall(product.details.product, :product, "")
          # initialize addons and the workflow manager
          Yast::AddOnProduct.SetBaseProductURL(base_url)
          Yast::WorkflowManager.SetBaseWorkflow(false)
          Yast::AutoinstFunctions.reset_product
        # report error only for installation or if autoupgrade contain addon with relative url.
        # This way autoupgrade for Full medium on registered system
        # can autoupgrade with empty profile.
        elsif !Yast::Mode.autoupgrade || addons_relurl
          msg = if Yast::Mode.autoupgrade && addons_relurl
            _("None or wrong base product has been defined " \
              "in the AutoYaST configuration file. " \
              "It needs to be specified as base for addons that use relurl scheme." \
              "Please check the <b>products</b> entry in the <b>software</b> section.<br><br>" \
              "Following base products are available:<br>")
          else
            _("None or wrong base product has been defined " \
              "in the AutoYaST configuration file. " \
              "Please check the <b>products</b> entry in the <b>software</b> section.<br><br>" \
              "Following base products are available:<br>")
          end
          Yast::AutoinstFunctions.available_base_products.each do |bp|
            # FIXME: here we abuse knowledge that base product is ProductLocation and not Product
            # so we access that details which is not available in Product
            msg += "#{bp.details.product} (#{bp.details.summary})<br>"
          end
          Yast::Popup.LongError(msg) # No timeout because we are stopping the installation/upgrade.
          return :abort
        end

        nil
      end
    end
  end
end
