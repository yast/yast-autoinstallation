# File:  include/autoinstall/dialogs.ycp
# Module:  Auto-Installation Configuration System
# Summary:  This module handles the configuration for auto-installation
# Authors:  Anas Nashif <nashif@suse.de>
# $Id$
module Yast
  module AutoinstallDialogsInclude
    def initialize_autoinstall_dialogs(include_target)
      Yast.import "UI"
      textdomain "autoinst"

      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Profile"
      Yast.import "Directory"
      Yast.import "Wizard"
      Yast.import "AutoinstConfig"
      Yast.import "AutoinstClass"
      Yast.import "Package"
      Yast.include include_target, "autoinstall/helps.rb"
    end

    # Preferences Dialog
    # @return [Symbol]
    def Settings
      Wizard.CreateDialog
      Wizard.SetDesktopIcon("org.opensuse.yast.AutoYaST")
      contents = HVSquash(
        VBox(
          VSquash(
            HBox(
              TextEntry(
                Id(:repository),
                _("&Profile Repository:"),
                AutoinstConfig.Repository
              ),
              VBox(
                VSpacing(),
                Bottom(PushButton(Id(:opendir), _("&Select Directory")))
              )
            )
          ),
          VSquash(
            HBox(
              TextEntry(
                Id(:classdir),
                _("&Class directory:"),
                AutoinstConfig.classDir
              ),
              VBox(
                VSpacing(),
                Bottom(PushButton(Id(:openclassdir), _("Select &Directory")))
              )
            )
          )
        )
      )

      help = _(
        "<P>\n" \
        "Enter the directory where all <em>control files</em> should be stored in\n" \
        "the <b>Repository</b> field.</P>"
      )

      help = Ops.add(
        help,
        _(
          "<P>If you are using the classes feature\n" \
          "of Autoyast, also enter the class directory. This is where\n" \
          "all class files are stored.</p>\n"
        )
      )

      Wizard.SetContents(_("Settings"), contents, help, true, true)

      Wizard.HideAbortButton
      Wizard.RestoreNextButton

      changed = false
      ret = :none
      loop do
        ret = Convert.to_symbol(UI.UserInput)

        new_rep = Convert.to_string(UI.QueryWidget(Id(:repository), :Value))
        new_classdir = Convert.to_string(UI.QueryWidget(Id(:classdir), :Value))

        case ret
        when :opendir
          new_rep = UI.AskForExistingDirectory(
            AutoinstConfig.Repository,
            _("Select Directory")
          )
          UI.ChangeWidget(Id(:repository), :Value, new_rep) if new_rep != ""
          next
        when :openclassdir
          new_classdir = UI.AskForExistingDirectory(
            AutoinstConfig.classDir,
            _("Select Directory")
          )
          UI.ChangeWidget(Id(:classdir), :Value, new_classdir) if new_classdir != ""
          next
        when :next
          if AutoinstConfig.Repository != new_rep
            changed = true
            AutoinstConfig.Repository = new_rep
          end
          if AutoinstConfig.classDir != new_classdir
            changed = true
            # AutoinstConfig::classDir = new_classdir;
            AutoinstClass.classDirChanged(new_classdir)
          end
        end
        break if ret == :back || ret == :next
      end

      Wizard.RestoreScreenShotName
      AutoinstConfig.Save if changed
      Wizard.CloseDialog
      ret
    end

    # Check validity of file name
    #
    # @param name [String] file name
    # @return [Integer] 0 if valid, -1 if not.
    def checkFileName(name)
      if name !=
          Builtins.filterchars(
            name,
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-"
          ) ||
          Ops.greater_than(Builtins.size(name), 127)
        return -1
      end

      0
    end

    # Return a message about invalid file names
    #
    # @return [String] message
    def invalidFileName
      _(
        "Invalid file name.\n" \
        "Names can only contain letters, numbers, and underscore,\n" \
        "must begin with letter, and must be\n" \
        "127 characters long or less.\n"
      )
    end

    # Popup for a new file name
    # @param [String] caption
    # @param [String] textentry
    # @return [String] new file name
    def NewFileName(caption, textentry)
      con = HBox(
        HSpacing(1),
        VBox(
          VSpacing(0.2),
          # Translators: popup dialog heading
          Heading(caption),
          #  _("&New Profile Name") _("New Profile")
          # Translators: text entry label
          Left(TextEntry(Id(:newname), textentry, "")),
          VSpacing(0.2),
          ButtonBox(
            PushButton(Id(:ok), Opt(:default), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          ),
          VSpacing(0.2)
        ),
        HSpacing(1)
      )

      UI.OpenDialog(Opt(:decorated), con)
      UI.SetFocus(Id(:newname))
      f = ""
      ret = nil
      loop do
        ret = UI.UserInput
        case ret
        when :cancel
          break
        when :ok
          f = Convert.to_string(UI.QueryWidget(Id(:newname), :Value))
          if checkFileName(f) != 0 || f == ""
            Popup.Error(invalidFileName)
            next
          end
          break
        end
      end

      UI.CloseDialog

      (ret == :ok) ? f : ""
    end

    # Clone running system
    # @return [Symbol]
    def cloneSystem
      Yast.import "AutoinstClone"
      Yast.import "Profile"

      Wizard.CreateDialog
      Wizard.SetDesktopIcon("org.opensuse.yast.CloneSystem")

      # title
      title = _("Create a Reference Control File")
      items = AutoinstClone.createClonableList
      contents = VBox(
        MultiSelectionBox(Id(:res), _("Select Additional Resources:"), items)
      )

      Wizard.SetContents(
        title,
        contents,
        Ops.get_string(@HELPS, "clone", ""),
        true,
        true
      )
      Wizard.HideAbortButton
      Wizard.SetNextButton(:next, Label.CreateButton)

      ret = :none
      loop do
        ret = Convert.to_symbol(UI.UserInput)
        if ret == :next
          AutoinstClone.additional = Convert.convert(
            UI.QueryWidget(Id(:res), :SelectedItems),
            from: "any",
            to:   "list <string>"
          )
          Popup.ShowFeedback(
            _("Collecting system data..."),
            _("This may take a while...")
          )
          AutoinstClone.Process
          Profile.changed = true
          Popup.ClearFeedback
        end
        break if ret == :next || ret == :back
      end
      Wizard.CloseDialog
      ret
    end

    def UpdateValidDialog(summary, log)
      UI.ChangeWidget(Id(:richtext), :Value, summary)
      UI.ChangeWidget(Id(:log), :LastLine, log)

      nil
    end

    # Validate Dialog
    # @return [Symbol]
    def ValidDialog
      Yast.import "Summary"
      Yast.import "HTML"
      Wizard.CreateDialog
      contents = VBox(
        RichText(Id(:richtext), Opt(:autoScrollDown), ""),
        LogView(Id(:log), "", 5, 100)
      )
      Wizard.SetContents(
        _("Check profile validity"),
        contents,
        Ops.get_string(@HELPS, "valid", ""),
        true,
        true
      )
      Builtins.y2milestone("Checking validity")
      Wizard.HideAbortButton
      Wizard.HideBackButton
      UI.ChangeWidget(Id(:next), :Label, Label.FinishButton)

      sectionFiles = Profile.SaveSingleSections(AutoinstConfig.tmpDir)
      Builtins.y2debug("Got section map: %1", sectionFiles)

      html_ok = HTML.Colorize(_("OK"), "green")
      html_ko = HTML.Colorize(_("Error"), "red")
      html_warn = HTML.Colorize(_("Warning"), "yellow")
      summary = ""

      # some of these can be commented out for the release
      validators = [
        #     [
        #   _("Checking XML without validation..."),
        #   "/usr/bin/xmllint --noout",
        #   ],
        #       [
        #     _("Checking XML with DTD validation..."),
        #     "/usr/bin/xmllint --noout --valid"
        #     ],
        [
          _("Checking XML with RNG validation..."),
          Ops.add(
            Ops.add(
              "/usr/bin/xmllint --noout --relaxng ",
              # was: /usr/share/autoinstall/rng/profile.rng
              Directory.schemadir
            ),
            "/autoyast/rng/profile.rng"
          )
        ]
      ]

      # section wise validation
      Builtins.foreach(validators) do |i|
        header = Ops.get_string(i, 0, "")
        summary = Summary.AddHeader(summary, header)
        UpdateValidDialog(summary, "")
        summary = Summary.OpenList(summary)
        Builtins.foreach(sectionFiles) do |section, sectionFile|
          cmd = Ops.add(Ops.add(Ops.get_string(i, 1, ""), " "), sectionFile)
          summary = Ops.add(
            Ops.add(summary, "<li>"),
            Builtins.sformat(_("Section %1: "), section)
          )
          UpdateValidDialog(summary, Ops.add(Ops.add("\n", cmd), "\n"))
          o = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
          Builtins.y2debug("validation output: %1", o)
          summary = Ops.add(
            summary,
            if Ops.get_integer(o, "exit", 1) != 0 ||
              (Ops.get_string(i, 2, "") == "jing sucks" &&
                Ops.greater_than(
                  Builtins.size(Ops.get_string(o, "stderr", "")),
                  0
                ))
              html_ko
            else
              html_ok
            end
          )
          UpdateValidDialog(summary, Ops.get_string(o, "stderr", ""))
        end
        summary = Summary.CloseList(summary)
      end

      # jing validation -- validates complete xml profile
      if Package.Installed("jing")
        complete_xml_file = Ops.add(
          Ops.add(AutoinstConfig.tmpDir, "/"),
          "valid.xml"
        )
        Profile.Save(complete_xml_file)
        validator = [
          _("Checking XML with RNC validation..."),
          Ops.add(
            Ops.add("/usr/bin/jing >&2 -c ", Directory.schemadir),
            "/autoyast/rnc/profile.rnc"
          ),
          "jing sucks"
        ]
        header = Ops.get_string(validator, 0, "")
        summary = Summary.AddHeader(summary, header)
        UpdateValidDialog(summary, "")
        cmd = Ops.add(
          Ops.add(Ops.get_string(validator, 1, ""), " "),
          complete_xml_file
        )
        UpdateValidDialog(summary, Ops.add(Ops.add("\n", cmd), "\n"))
        o = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
        Builtins.y2debug("validation output: %1", o)
        summary = Ops.add(
          summary,
          if Ops.get_integer(o, "exit", 1) != 0 ||
            Ops.greater_than(Builtins.size(Ops.get_string(o, "stderr", "")), 0)
            html_ko
          else
            html_ok
          end
        )
        UpdateValidDialog(summary, Ops.get_string(o, "stderr", ""))
      end

      logicOk = true
      rootOk = false
      if Builtins.haskey(Profile.current, "users")
        Builtins.foreach(Ops.get_list(Profile.current, "users", [])) do |u|
          if Ops.get_string(u, "username", "") == "root" &&
              Builtins.haskey(u, "user_password")
            rootOk = true
          end
        end
      end
      # the autoyast interface can check if the profile is logical or if important stuff is missing
      # the missing stuff is under the Label "Logic"
      summary = Summary.AddHeader(summary, _("Logic"))
      if !rootOk
        # the autoyast config frontend can check if a root password is configured
        # and can warn the user if it is missing
        summary = Ops.add(
          Ops.add(Ops.add(summary, html_warn), " "),
          _("No root password configured")
        )
        logicOk = false
      end

      summary = Ops.add(summary, html_ok) if logicOk
      UpdateValidDialog(summary, "")

      ret = nil
      loop do
        ret = UI.UserInput
        case ret
        when :next, :back, :abort
          break
        end
      end

      Wizard.CloseDialog
      Convert.to_symbol(ret)
    end
  end
end
