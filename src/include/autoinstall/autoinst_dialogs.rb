# encoding: utf-8

# File:  modules/ProfileLocation.ycp
# Package:  Auto-installation
# Summary:  Process Auto-Installation Location
# Author:  Anas Nashif <nashif@suse.de>
#
# $Id$
module Yast
  module AutoinstallAutoinstDialogsInclude
    def initialize_autoinstall_autoinst_dialogs(_include_target)
      textdomain "autoinst"
      Yast.import "Label"
      Yast.import "Popup"
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

      UI.OpenDialog(
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
                PushButton(Id(:retry), Opt(:default), Label.RetryButton),
                PushButton(Id(:abort), Label.AbortButton)
              )
            )
          )
        )
      )

      uri = ""
      loop do
        ret = Convert.to_symbol(UI.UserInput)

        if ret == :abort && Popup.ConfirmAbort(:painless)
          break
        elsif ret == :retry
          uri = Convert.to_string(UI.QueryWidget(Id(:uri), :Value))
          if uri == ""
            next
          else
            break
          end
        end
      end

      UI.CloseDialog
      uri
    end
  end
end
