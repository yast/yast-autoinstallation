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

require "installation/auto_client"

Yast.import "AutoinstFile"

module Y2Autoinstallation
  module Clients
    class FilesAuto < ::Installation::AutoClient
      include Yast::I18n

      def initialize
        super
        textdomain "autoinst"
      end

      def import(map)
        Yast::AutoinstFile.Import(map)
      end

      def export
        Yast::AutoinstFile.Export
      end

      def summary
        Yast::AutoinstFile.Summary
      end

      def reset
        Yast::AutoinstFile.Import([])
      end

      def packages
        {}
      end

      def write
        Yast::AutoinstFile.Write
      end

      def modified?
        Yast::AutoinstFile.GetModified
      end

      def modified
        Yast::AutoinstFile.SetModified
      end

      def change
        Wizard.CreateDialog
        Wizard.SetDesktopIcon("org.opensuse.yast.AutoYaST")
        custom_file_dialog
      ensure
        Wizard.CloseDialog
      end

    private

      # Add or edit a file
      # @todo move to own dialog class
      def AddEditFile(fileName, source, permissions, owner, location)
        modified = false
        AutoinstFile.Files = Builtins.maplist(AutoinstFile.Files) do |file|
          # Edit
          if Ops.get_string(file, "file_path", "") == fileName
            oldFile = {}
            oldFile = Builtins.add(oldFile, "file_path", fileName)
            oldFile = Builtins.add(oldFile, "file_contents", source)
            oldFile = Builtins.add(oldFile, "file_permissions", permissions)
            oldFile = Builtins.add(oldFile, "file_owner", owner)
            oldFile = Builtins.add(oldFile, "file_location", location)
            modified = true
            next deep_copy(oldFile)
          else
            next deep_copy(file)
          end
        end

        if !modified
          file = {}
          file = Builtins.add(file, "file_path", fileName)
          file = Builtins.add(file, "file_contents", source)
          file = Builtins.add(file, "file_permissions", permissions)
          file = Builtins.add(file, "file_owner", owner)
          file = Builtins.add(file, "file_location", location)
          AutoinstFile.Files = Builtins.add(AutoinstFile.Files, file)
        end
        nil
      end

      # delete a file from a list
      # @param fileName [String] file name
      # @return [Array<Hash>] modified list of files
      def deleteFile(fileName)
        new = Builtins.filter(AutoinstFile.Files) do |s|
          Ops.get_string(s, "file_path", "") != fileName
        end
        deep_copy(new)
      end

      # Dialog for adding a file
      #
      def addFileDialog(mode, name)
        file = {}
        if mode == :edit
          filtered_files = Builtins.filter(AutoinstFile.Files) do |s|
            Ops.get_string(s, "file_path", "") == name
          end
          if Ops.greater_than(Builtins.size(filtered_files), 0)
            file = Ops.get_map(filtered_files, 0, {})
          end
        end

        # help 1/2
        help = _(
          "<p>Using this dialog, copy the contents of the file and specify the final\n" \
          "path on the installed system. YaST will copy this file to the specified location.</p>"
        )

        # help 2/2
        help = Ops.add(
          help,
          _(
            "<p>To protect copied files, set the owner and the permissions of the files.\n" \
            "Set the owner using the syntax <i>userid:groupid</i>. "\
            "Permissions can be a symbolic\n" \
            "representation of changes to make or an octal number " \
            "representing the bit pattern for the\n" \
            "new permissions.</p>"
          )
        )

        title = _("Configuration File Editor")

        contents = VBox(
          HBox(
            TextEntry(
              Id(:filename),
              _("&File Path"),
              Ops.get_string(file, "file_path", "")
            ),
            HStretch(),
            Empty()
          ),
          HBox(
            TextEntry(
              Id(:owner),
              _("&Owner"),
              Ops.get_string(file, "file_owner", "")
            ),
            HStretch(),
            TextEntry(
              Id(:perm),
              _("&Permissions"),
              Ops.get_string(file, "file_permissions", "")
            )
          ),
          VSpacing(1),
          TextEntry(
            Id(:location),
            Opt(:notify),
            _("&Retrieve from"),
            Ops.get_string(file, "file_location", "")
          ),
          HBox(
            MultiLineEdit(
              Id(:source),
              Opt(:notify),
              _("File So&urce"),
              Ops.get_string(file, "file_contents", "")
            )
          ),
          VSpacing(1),
          HBox(PushButton(Id(:loadsource), _("&Load new contents")))
        )

        Wizard.SetContents(title, contents, help, true, true)

        Wizard.SetNextButton(:next, Label.SaveButton)

        # why?
        #     if (mode == `edit)
        #     {
        #       UI::ChangeWidget(`id(`filename), `Enabled, false);
        #     }

        ret = nil
        loop do
          if Convert.to_string(UI.QueryWidget(Id(:location), :Value)) == ""
            UI.ChangeWidget(Id(:source), :Enabled, true)
            if Convert.to_string(UI.QueryWidget(Id(:source), :Value)) == ""
              UI.ChangeWidget(Id(:location), :Enabled, true)
            else
              UI.ChangeWidget(Id(:location), :Enabled, false)
              UI.ChangeWidget(Id(:location), :Value, "")
            end
          else
            UI.ChangeWidget(Id(:source), :Enabled, false)
          end
          ret = Convert.to_symbol(UI.UserInput)
          case ret
          when :next
            fileName = Convert.to_string(UI.QueryWidget(Id(:filename), :Value))
            permissions = Convert.to_string(UI.QueryWidget(Id(:perm), :Value))
            owner = Convert.to_string(UI.QueryWidget(Id(:owner), :Value))
            source = Convert.to_string(UI.QueryWidget(Id(:source), :Value))
            location = Convert.to_string(UI.QueryWidget(Id(:location), :Value))

            if (source == "" && location == "") || fileName == ""
              Popup.Message(
                _(
                  "Provide at least the file\nname and the contents of the file.\n"
                )
              )
              ret = :again
              next
            else
              AddEditFile(fileName, source, permissions, owner, location)
            end
          when :loadsource
            filename = UI.AskForExistingFile("", "*", _("Select a file to load."))
            if filename != ""
              source = Convert.to_string(
                SCR.Read(path(".target.string"), filename)
              )
              UI.ChangeWidget(Id(:source), :Value, source)
              next
            end
          end
          break if [:next, :back, :cancel].include?(ret)
        end
        Wizard.SetNextButton(:next, Label.FinishButton)
        Convert.to_symbol(ret)
      end

      # Summary of configuration
      def dialog_contents
        allfiles = Builtins.maplist(AutoinstFile.Files) do |s|
          Item(
            Id(Ops.get_string(s, "file_path", "Unknown")),
            Ops.get_string(s, "file_path", "Unknown"),
            Ops.get_string(s, "file_owner", ""),
            Ops.get_string(s, "file_permissions", "")
          )
        end
        contents = VBox(
          Left(Label(_("Available Files"))),
          Table(
            Id(:table),
            Opt(:notify),
            Header(_("File Path"), _("Owner"), _("Permissions")),
            allfiles
          ),
          HBox(
            PushButton(Id(:new), Label.NewButton),
            PushButton(Id(:edit), Label.EditButton),
            PushButton(Id(:delete), Label.DeleteButton)
          )
        )
        deep_copy(contents)
      end

      # @todo own dialog class
      def custom_file_dialog
        title = _("Add Complete Configuration Files")

        help = _(
          "<p>For many applications and services, you might have prepared\n" \
          "a configuration file that should be copied in a complete form to a location in the\n" \
          "installed system. For example, this is the case if you are installing a web server\n" \
          "and have an httpd.conf configuration file prepared.</p>"
        )

        Wizard.SetContents(title, dialog_contents, help, true, true)

        Wizard.SetNextButton(:next, Label.FinishButton)
        Wizard.HideAbortButton
        select_msg = _("Select a file from the table first.")
        ret = nil
        loop do
          ret = Convert.to_symbol(UI.UserInput)

          case ret
          when :new
            addFileDialog(Convert.to_symbol(ret), "")
          when :edit
            name = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
            if name
              addFileDialog(Convert.to_symbol(ret), name)
            else
              Popup.Message(select_msg)
              next
            end
          when :delete
            name = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
            if name
              AutoinstFile.Files = deleteFile(name)
            else
              Popup.Message(select_msg)
              next
            end
          end
          Wizard.SetContents(title, dialog_contents, help, true, true)
          break if [:back, :next, :cancel].include?(ret)
        end

        Convert.to_symbol(ret)
      end
    end
  end
end
