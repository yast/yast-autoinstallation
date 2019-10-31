# encoding: utf-8

# File:  clients/autoyast.ycp
# Summary:  Main file for client call
# Authors:  Anas Nashif <nashif@suse.de>
#
# $Id$
module Yast
  module AutoinstallWizardsInclude
    def initialize_autoinstall_wizards(include_target)
      textdomain "autoinst"
      Yast.import "Wizard"
      Yast.import "Label"
      Yast.include include_target, "autoinstall/classes.rb"
      Yast.include include_target, "autoinstall/dialogs.rb"
    end

    # Whole configuration of autoyast
    # @return `back, `abort or `next
    def AutoSequence
      dialogs = {
        "main"     => -> { MainDialog() },
        "settings" => -> { Settings() },
        "clone"    => -> { cloneSystem },
        "classes"  => -> { ManageClasses() },
        "merge"    => -> { MergeDialog() },
        "valid"    => -> { ValidDialog() }
      }

      sequence = {
        "ws_start" => "main",
        "main"     => {
          menu_exit:     :ws_finish,
          menu_settings: "settings",
          menu_merge:    "merge",
          menu_classes:  "classes",
          menu_clone:    "clone",
          menu_valid:    "valid"
        },
        "merge"    => { next: "main", abort: "main", back: "main" },
        "valid"    => { next: "main", abort: "main", back: "main" },
        "classes"  => { next: "main", abort: "main", back: "main" },
        "clone"    => { next: "main", abort: "main", back: "main" },
        "settings" => { next: "main", back: "main" }
      }

      # Translators: dialog caption
      caption = _("Autoinstall Configuration")
      contents = Label(_("Initializing ..."))
      Wizard.CreateDialog
      Wizard.SetContentsButtons(
        caption,
        contents,
        AutoinstConfig.MainHelp,
        Label.BackButton,
        Label.NextButton
      )

      CreateDialog("System", "general")
      menus

      ret = Sequencer.Run(dialogs, sequence)
      UI.CloseDialog
      ret
    end
  end
end
