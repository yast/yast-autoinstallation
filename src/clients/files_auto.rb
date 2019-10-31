# File:  clients/autoinst_files.ycp
# Package:  Configuration of XXpkgXX
# Summary:  Client for autoinstallation
# Authors:  Anas Nashif <nashif@suse.de>
#
# $Id$
#
# This is a client for autoinstallation. It takes its arguments,
# goes through the configuration and return the setting.
# Does not do any changes to the configuration.

# @param function to execute
# @param list of file settings
# @return [Hash] edited settings, Summary or boolean on success depending on called function
# @example map mm = $[ "FAIL_DELAY" : "77" ];
# @example map ret = WFM::CallFunction ("autoinst_files", [ "Summary", mm ]);
module Yast
  class FilesAutoClient < Client
    def main
      Yast.import "UI"

      textdomain "autoinst"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Files auto started")

      Yast.import "AutoinstFile"
      Yast.import "Wizard"
      Yast.import "Popup"
      Yast.import "Label"

      @ret = nil
      @func = ""
      @param = []

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_list?(WFM.Args(1))
          @param = Convert.to_list(WFM.Args(1))
        end
      end

      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      # Import Data
      if @func == "Import"
        @ret = AutoinstFile.Import(
          Convert.convert(@param, from: "list", to: "list <map>")
        )
        if @ret.nil?
          Builtins.y2error(
            "Parameter to 'Import' is probably wrong, should be list of maps"
          )
          @ret = false
        end
      # Create a  summary
      elsif @func == "Summary"
        @ret = AutoinstFile.Summary
        if @ret.nil?
          Builtins.y2error(
            "Parameter to 'Import' is probably wrong, should be list of maps"
          )
          @ret = false
        end
      # Reset configuration
      elsif @func == "Reset"
        AutoinstFile.Import([])
        @ret = []
      # Change configuration (run AutoSequence)
      elsif @func == "Change"
        Wizard.CreateDialog
        Wizard.SetDesktopIcon("org.opensuse.yast.AutoYaST")
        @ret = CustomFileDialog()
        Wizard.CloseDialog
      elsif @func == "Packages"
        @ret = {}
      # Return actual state
      elsif @func == "Export"
        @ret = AutoinstFile.Export
      # Write givven settings
      elsif @func == "Write"
        @ret = AutoinstFile.Write
      elsif @func == "GetModified"
        @ret = AutoinstFile.GetModified
      elsif @func == "SetModified"
        AutoinstFile.SetModified
      else
        Builtins.y2error("Unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("Files auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)

      # EOF
    end

    # Add or edit a file
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
      begin
        if Convert.to_string(UI.QueryWidget(Id(:location), :Value)) != ""
          UI.ChangeWidget(Id(:source), :Enabled, false)
        else
          UI.ChangeWidget(Id(:source), :Enabled, true)
          if Convert.to_string(UI.QueryWidget(Id(:source), :Value)) != ""
            UI.ChangeWidget(Id(:location), :Enabled, false)
            UI.ChangeWidget(Id(:location), :Value, "")
          else
            UI.ChangeWidget(Id(:location), :Enabled, true)
          end
        end
        ret = Convert.to_symbol(UI.UserInput)
        if ret == :next
          fileName = Convert.to_string(UI.QueryWidget(Id(:filename), :Value))
          permissions = Convert.to_string(UI.QueryWidget(Id(:perm), :Value))
          owner = Convert.to_string(UI.QueryWidget(Id(:owner), :Value))
          source = Convert.to_string(UI.QueryWidget(Id(:source), :Value))
          location = Convert.to_string(UI.QueryWidget(Id(:location), :Value))

          if source == "" && location == "" || fileName == ""
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
        elsif ret == :loadsource
          filename = UI.AskForExistingFile("", "*", _("Select a file to load."))
          if filename != ""
            source = Convert.to_string(
              SCR.Read(path(".target.string"), filename)
            )
            UI.ChangeWidget(Id(:source), :Value, source)
            next
          end
        end
      end until ret == :next || ret == :back || ret == :cancel
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

    def CustomFileDialog
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
      begin
        ret = Convert.to_symbol(UI.UserInput)

        if ret == :new
          addFileDialog(Convert.to_symbol(ret), "")
        elsif ret == :edit
          name = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
          if !name.nil?
            addFileDialog(Convert.to_symbol(ret), name)
          else
            Popup.Message(select_msg)
            next
          end
        elsif ret == :delete
          name = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
          if !name.nil?
            AutoinstFile.Files = deleteFile(name)
          else
            Popup.Message(select_msg)
            next
          end
        end
        Wizard.SetContents(title, dialog_contents, help, true, true)
      end until ret == :back || ret == :next || ret == :cancel

      Convert.to_symbol(ret)
    end
  end
end

Yast::FilesAutoClient.new.main
