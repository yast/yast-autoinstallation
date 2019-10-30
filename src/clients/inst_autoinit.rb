# encoding: utf-8

# File:	clients/inst_autoinit.ycp
# Package:	Auto-installation
# Summary:	Parses XML Profile for automatic installation
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
#

require "autoinstall/autosetup_helpers"
require "y2packager/medium_type"

module Yast
  class InstAutoinitClient < Client
    include Y2Autoinstallation::AutosetupHelpers
    include Yast::Logger

    def main
      Yast.import "UI"

      textdomain "autoinst"

      Yast.import "AutoInstall"
      Yast.import "AutoInstallRules"
      Yast.import "AutoinstConfig"
      Yast.import "AutoinstFunctions"
      Yast.import "AutoinstGeneral"
      Yast.import "Call"
      Yast.import "Console"
      Yast.import "InstURL"
      Yast.import "Installation"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Profile"
      Yast.import "ProfileLocation"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "URL"
      Yast.import "Y2ModuleConfig"

      Yast.include self, "autoinstall/autoinst_dialogs.rb"

      Console.Init

      @help_text = _(
        "<p>\nPlease wait while the system is prepared for autoinstallation.</p>\n"
      )
      @progress_stages = [
        _("Probe hardware"),
        _("Retrieve & Read Control File"),
        _("Parse control file"),
        _("Initial Configuration"),
      ]
      @profileFetched = false

      Progress.New(
        _("Preparing System for Automatic Installation"),
        "", # progress_title
        6, # progress bar length
        @progress_stages,
        [],
        @help_text
      )
      Progress.NextStage
      Progress.Title(_("Preprobing stage"))
      Builtins.y2milestone("pre probing")

      @tmp = Convert.to_string(
        SCR.Read(path(".target.string"), "/etc/install.inf")
      )
      if @tmp != nil && Builtins.issubstring(Builtins.tolower(@tmp), "iscsi: 1")
        WFM.CallFunction("inst_iscsi-client", [])
      end

      Progress.NextStep
      Progress.Title(_("Probing hardware..."))
      Builtins.y2milestone("Probing hardware...")

      if !@profileFetched
        # if profile is defined, first read it, then probe hardware
        @autoinstall = SCR.Read(path(".etc.install_inf.AutoYaST"))
        if Mode.autoupgrade &&
            !(@autoinstall != nil && Ops.is_string?(@autoinstall) &&
              Convert.to_string(@autoinstall) != "")
          AutoinstConfig.ParseCmdLine("file:///mnt/root/autoupg.xml")
          AutoinstConfig.ProfileInRootPart = true
        end

        @ret = processProfile
        return @ret if @ret != :ok
      end

      Progress.Finish

      # when installing from the online installation medium we need to
      # register the system earlier because the medium does not contain any
      # repositories, we need the repositories from the registration server
      # TODO: maybe we will need it also in the autoupgrade case...
      if Y2Packager::MediumType.online?
        # check that the registration section is defined and registration is enabled
        reg_section = Yast::Profile.current.fetch(REGISTER_SECTION, {})
        reg_enabled = reg_section["do_registration"]

        if !reg_enabled
          msg = _("Registration is mandatory when using the online " \
            "installation medium. Enable registration in " \
            "the AutoYaST profile.")
          Popup.LongError(msg)  # No timeout because we are stopping the installation/upgrade.

          return :abort
        end

        suse_register if !Mode.autoupgrade
      # offline registration need here to init software management according to picked product
      elsif Y2Packager::MediumType.offline?
        product = AutoinstFunctions.selected_product

        # duplicite code, but for offline medium we need to do it before system is initialized as
        # we get need product for initialize libzypp, but for others we need first init libzypp
        # to get available products.
        if !product
          msg = _("None or wrong base product has been defined in the AutoYaST configuration file. " \
          "Please check the <b>products</b> entry in the <b>software</b> section.<br><br>" \
          "Following base products are available:<br>")
          AutoinstFunctions.available_base_products.each do |product|
            msg += "#{product.name} (#{product.display_name})<br>"
          end
          Popup.LongError(msg) # No timeout because we are stopping the installation/upgrade.
          return :abort
        end

        show_popup = true
        base_url = Yast::InstURL.installInf2Url("")
        log_url = Yast::URL.HidePassword(base_url)
        Yast::Packages.Initialize_StageInitial(show_popup, base_url, log_url, @product.dir)
        # select the product to install
        Yast::Pkg.ResolvableInstall(@product.details && @product.details.product, :product, "")
        # initialize addons and the workflow manager
        Yast::AddOnProduct.SetBaseProductURL(base_url)
        Yast::WorkflowManager.SetBaseWorkflow(false)
      end

      if !(Mode.autoupgrade && AutoinstConfig.ProfileInRootPart)
        @ret = WFM.CallFunction("inst_system_analysis", [])
        return @ret if @ret == :abort
      end

      if Builtins.haskey(Profile.current, "iscsi-client")
        Builtins.y2milestone("iscsi-client found")
        WFM.CallFunction(
          "iscsi-client_auto",
          ["Import", Ops.get_map(Profile.current, "iscsi-client", {})]
        )
        WFM.CallFunction("iscsi-client_auto", ["Write"])
      end

      if Builtins.haskey(Profile.current, "fcoe-client")
        Builtins.y2milestone("fcoe-client found")
        WFM.CallFunction(
          "fcoe-client_auto",
          ["Import", Ops.get_map(Profile.current, "fcoe-client", {})]
        )
        WFM.CallFunction("fcoe-client_auto", ["Write"])
      end

      if !Y2Packager::MediumType.offline? && !AutoinstFunctions.selected_product
        msg = _("None or wrong base product has been defined in the AutoYaST configuration file. " \
         "Please check the <b>products</b> entry in the <b>software</b> section.<br><br>" \
         "Following base products are available:<br>")
        AutoinstFunctions.available_base_products.each do |product|
          msg += "#{product.name} (#{product.display_name})<br>"
        end
        Popup.LongError(msg) # No timeout because we are stopping the installation/upgrade.
        return :abort
      end

      return :abort if Popup.ConfirmAbort(:painless) if UI.PollInput == :abort

      :next
    end

  private

    # Checking profile for unsupported sections.
    def check_unsupported_profile_sections
      unsupported_sections = Y2ModuleConfig.unsupported_profile_sections
      if unsupported_sections.any?
        log.error "Could not process these unsupported profile " \
          "sections: #{unsupported_sections}"
        Report.LongWarning(
          # TRANSLATORS: Error message, %s is replaced by newline-separated
          # list of unsupported sections of the profile
          # Do not translate words in brackets
          _(
            "These sections of AutoYaST profile are not supported " \
            "anymore:<br><br>%s<br><br>" \
            "Please, use, e.g., &lt;scripts/&gt; or &lt;files/&gt;" \
            " to change the configuration."
          ) % unsupported_sections.map{|section| "&lt;#{section}/&gt;"}.join("<br>")
        )
      end
    end

    def processProfile
      Progress.NextStage
      Builtins.y2milestone("Starting processProfile msg:%1",AutoinstConfig.message)
      Progress.Title(AutoinstConfig.message)
      ret = false
      Progress.NextStep
      while true
        r = ProfileLocation.Process
        if r
          break
        else
          newURI = ProfileSourceDialog(AutoinstConfig.OriginalURI)
          if newURI == ""
            return :abort
          else
            # Updating new URI in /etc/install.inf (bnc#963487)
            # SCR.Write does not work in inst-sys here.
            WFM.Execute(
              path(".local.bash"),
              "sed -i \'/AutoYaST:/c\AutoYaST: #{newURI}\' /etc/install.inf"
            )

            AutoinstConfig.ParseCmdLine(newURI)
            AutoinstConfig.SetProtocolMessage
            next
          end
        end
      end

      return :abort if Popup.ConfirmAbort(:painless) if UI.PollInput == :abort

      #
      # Set reporting behaviour to default, changed later if required
      #
      Report.LogMessages(true)
      Report.LogErrors(true)
      Report.LogWarnings(true)

      return :abort if Popup.ConfirmAbort(:painless) if UI.PollInput == :abort

      Progress.NextStage
      Progress.Title(_("Parsing control file"))
      Builtins.y2milestone("Parsing control file")
      if !Profile.ReadXML(AutoinstConfig.xml_tmpfile) || Profile.current == {} ||
          Profile.current == nil
        Popup.Error(
          _(
            "Error while parsing the control file.\n" +
              "Check the log files for more details or fix the\n" +
              "control file and try again.\n"
          )
        )
        return :abort
      end

      Builtins.y2debug("Autoinstall control file %1", Profile.current)

      # Checking profile for unsupported sections.
      check_unsupported_profile_sections

      Progress.NextStage
      Progress.Title(_("Initial Configuration"))
      Builtins.y2milestone("Initial Configuration")
      Report.Import(Profile.current.fetch("report",{}))
      AutoinstGeneral.Import(Profile.current.fetch("general",{}))

      #
      # Copy the control file for easy access by user to  a pre-defined
      # directory
      #
      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat(
          "cp %1 %2/autoinst.xml",
          AutoinstConfig.xml_tmpfile,
          AutoinstConfig.profile_dir
        )
      )
      :ok
    end
  end
end

Yast::InstAutoinitClient.new.main
