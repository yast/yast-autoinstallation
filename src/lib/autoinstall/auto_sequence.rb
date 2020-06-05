# Copyright (c) [2020] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "ui/sequence"

Yast.import "Wizard"

module Y2Autoinstallation
  # Main AutoYaST UI sequence
  #
  # This is the sequence that drives the AutoYaST UI. It uses several dialogs that are defined in
  # some `include/autoinstall` modules.
  class AutoSequence < ::UI::Sequence
    include Yast
    include Yast::UIShortcuts

    SEQUENCE_HASH = {
      START      => "main",
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
    }.freeze

    def initialize
      super
      textdomain "autoinst"
      Yast.include self, "autoinstall/classes.rb"
      Yast.include self, "autoinstall/conftree.rb"
      Yast.include self, "autoinstall/dialogs.rb"
    end

    def run
      Yast::Wizard.CreateDialog
      Yast::Wizard.SetContentsButtons(
        _("Autoinstall Configuration"),
        Label(_("Initializing ...")),
        Yast::AutoinstConfig.MainHelp,
        Yast::Label.BackButton,
        Yast::Label.NextButton
      )

      CreateDialog("System", "general")
      menus
      ret = super(sequence: SEQUENCE_HASH)
      Yast::Wizard.CloseDialog
      ret
    end

  private

    # Main dialog
    #
    # @see AutoinstallConftreeInclude#MainDialog
    def main
      MainDialog()
    end

    # Settings dialog
    #
    # @see AutoinstallDialogsInclude#Settings
    def settings
      Settings()
    end

    # Dialog to clone the system
    #
    # @see AutoinstallDialogsInclude#cloneSystem
    def clone
      cloneSystem
    end

    # Dialog to manage AutoYaST classes
    #
    # @see AutoinstallClassesInclude#ManageClasses
    def classes
      ManageClasses()
    end

    # Dialog to merge classes
    #
    # @see AutoinstallClassesInclude#MergeDialog
    def merge
      MergeDialog()
    end

    # Dialog to validate a profile
    #
    # @see AutoinstallDialogsInclude#ValidDialog
    def valid
      ValidDialog()
    end
  end
end
