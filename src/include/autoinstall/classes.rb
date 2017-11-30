# encoding: utf-8

# File:	clients/autoinst_linuxrc.ycp
# Package:	Autoinstallation Configuration System
# Summary: 	Linuxrc Settings
# Authors:	Anas Nashif<nashif@suse.de>
#
# $Id$
module Yast
  module AutoinstallClassesInclude
    def initialize_autoinstall_classes(include_target)
      textdomain "autoinst"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "AutoinstClass"
      Yast.import "XML"
    end

    # XML_cleanup()
    # @return [Boolean]
    def XML_cleanup(_in, out)
      ycpin = XML.XMLToYCPFile(_in)
      Builtins.y2debug("Writing clean XML file to  %1, YCP is (%2)", out, ycpin)
      XML.YCPToXMLFile(:profile, ycpin, out)
    end


    # class_dialog_contents()
    # @return [Yast::Term]
    def class_dialog_contents
      classes = Builtins.maplist(AutoinstClass.Classes) do |_class|
        pathtoClass = Builtins.sformat(
          "%1/%2",
          AutoinstConfig.classDir,
          Ops.get_string(_class, "name", "Unknown")
        )
        files_in_class = Convert.to_list(
          SCR.Read(path(".target.dir"), pathtoClass)
        )
        Builtins.y2milestone("class: %1", _class)
        i = Item(
          Id(Ops.get_string(_class, "name", "Unknown")),
          Ops.get_string(_class, "name", "No name"),
          Ops.get_integer(_class, "order", 0),
          Builtins.size(files_in_class)
        )
        deep_copy(i)
      end

      contents = VBox(
        VWeight(
          40,
          Table(
            Id(:table),
            Opt(:notify, :immediate),
            Header(_("Class Name"), _("Order"), _("Configurations")),
            classes
          )
        ),
        VSpacing(1),
        VWeight(40, RichText(Id(:description), _("Class Description"))),
        VSpacing(1),
        HBox(
          PushButton(Id(:new), _("Ne&w")),
          PushButton(Id(:edit), _("&Edit")),
          PushButton(Id(:delete), _("&Delete"))
        )
      )
      deep_copy(contents)
    end



    # AddEditClasses()
    # Add or Edit a class
    # @param mode [Symbol] mode (:new or :edit)
    # @param name [String] class name
    def AddEditClasses(mode, name)
      classNames = Builtins.maplist(AutoinstClass.Classes) do |c|
        Ops.get_string(c, "name", "")
      end

      _class = {}
      if mode == :edit
        cl = Builtins.filter(AutoinstClass.Classes) do |c|
          Ops.get_string(c, "name", "") == name
        end
        class2 = Ops.get_map(cl, 0, {})
      end

      tmp = Builtins.sformat(
        "%1",
        Ops.add(Builtins.size(AutoinstClass.Classes), 1)
      )
      order = Builtins.tointeger(Ops.get_string(_class, "order", tmp))

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(0.5),
          VBox(
            Heading(_("Edit or Create Classes")),
            VSpacing(1),
            HBox(
              TextEntry(
                Id(:name),
                _("Na&me"),
                Ops.get_string(_class, "name", "")
              ),
              IntField(
                Id(:order),
                _("Or&der:"),
                1,
                10,
                Ops.get_integer(_class, "order", order)
              )
            ),
            MultiLineEdit(
              Id(:description),
              Opt(:hstretch),
              _("Descri&ption:"),
              Ops.get_string(_class, "description", "")
            ),
            VSpacing(1),
            ButtonBox(
              PushButton(Id(:save), Label.SaveButton),
              PushButton(Id(:cancel), Label.CancelButton)
            )
          ),
          HSpacing(0.5)
        )
      )
      UI.ChangeWidget(Id(:name), :Enabled, false) if mode == :edit
      ret = :none
      begin
        ret = Convert.to_symbol(UI.UserInput)
        if ret == :save
          if Convert.to_string(UI.QueryWidget(Id(:name), :Value)) == ""
            Popup.Message(_("That name is already used. Select another name."))
            ret = :again
            next
          end
          if mode != :edit &&
              Builtins.contains(classNames, UI.QueryWidget(Id(:name), :Value))
            Popup.Message(_("That name is already used. Select another name."))
            ret = :again
            next
          end
          name2 = Convert.to_string(UI.QueryWidget(Id(:name), :Value))
          if checkFileName(name2) != 0 || name2 == ""
            Popup.Error(invalidFileName)
            ret = :again
            next
          end
          newClass = {
            "name"        => name2,
            "order"       => Convert.to_integer(
              UI.QueryWidget(Id(:order), :Value)
            ),
            "description" => Convert.to_string(
              UI.QueryWidget(Id(:description), :Value)
            )
          }
          if mode == :new
            AutoinstClass.Classes = Builtins.add(
              AutoinstClass.Classes,
              newClass
            )
            SCR.Execute(
              path(".target.mkdir"),
              Ops.add(Ops.add(AutoinstConfig.classDir, "/"), name2)
            )
          else
            AutoinstClass.Classes = Builtins.maplist(AutoinstClass.Classes) do |c|
              if Ops.get_string(c, "name", "") ==
                  Convert.to_string(UI.QueryWidget(Id(:name), :Value))
                next deep_copy(newClass)
              else
                next deep_copy(c)
              end
            end
          end
        end
      end until ret == :save || ret == :cancel

      UI.CloseDialog

      ret
    end




    # Manage Classes
    #
    def ManageClasses
      Wizard.CreateDialog
      title = _("Classes")

      help = _(
        "<p>Use this interface to define classes of control files. </p>\n"
      )

      help = Ops.add(
        help,
        _(
          "<p>For example, you can define a class of configurations for\na specific  department, group, or site in your company environment.</p>\n"
        )
      )

      help = Ops.add(
        help,
        _(
          "<p>The order (priority) defines the hierarchy of a class\n" +
            "and when it is merged when creating a control file.\n" +
            "</p>\n"
        )
      )


      Wizard.SetContents(title, class_dialog_contents, help, true, true)

      Wizard.HideAbortButton
      Wizard.SetNextButton(:next, Label.FinishButton)

      Wizard.HideAbortButton
      ret = nil
      begin
        if Builtins.size(AutoinstClass.Classes) == 0
          UI.ChangeWidget(Id(:edit), :Enabled, false)
          UI.ChangeWidget(Id(:delete), :Enabled, false)
        end

        _class = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
        cl = Builtins.filter(AutoinstClass.Classes) do |c|
          Ops.get_string(c, "name", "") == _class
        end
        selected_class = Ops.get_map(cl, 0, {})
        if _class != nil
          UI.ChangeWidget(
            Id(:description),
            :Value,
            Ops.get_locale(selected_class, "description", _("No Description"))
          )
        end

        ret = Convert.to_symbol(UI.UserInput)

        if ret == :new
          defret = AddEditClasses(Convert.to_symbol(ret), "")

          Wizard.SetContents(title, class_dialog_contents, help, true, true)
        elsif ret == :edit
          if _class == nil
            Popup.Message(_("Select at least one class\nto edit.\n"))
            next
          end
          defret = AddEditClasses(Convert.to_symbol(ret), _class)
          Wizard.SetContents(title, class_dialog_contents, help, true, true)
        elsif ret == :delete
          if _class == nil
            Popup.Message(_("Select at least one class\nto delete.\n"))
            next
          end
          AutoinstClass.Classes = Builtins.filter(AutoinstClass.Classes) do |c|
            Ops.get_string(c, "name", "") != _class
          end
          AutoinstClass.deletedClasses = Builtins.add(
            AutoinstClass.deletedClasses,
            _class
          )

          Wizard.SetContents(title, class_dialog_contents, help, true, true)
        end
      end until ret == :back || ret == :next

      AutoinstClass.Save if ret == :next
      Wizard.CloseDialog
      Convert.to_symbol(ret)
    end


    # GetClassOrder()
    # @param name [String] class name
    # @return [Fixnum] class order
    def GetClassOrder(name)
      order = 0
      Builtins.foreach(AutoinstClass.Classes) do |_class|
        if Ops.get_string(_class, "name", "") == name
          order = Ops.get_integer(_class, "order", 0)
        end
      end
      order
    end




    # The merge operation
    def MergeAll(selected_profiles, base)
      selected_profiles = deep_copy(selected_profiles)
      tmpdir = AutoinstConfig.tmpDir
      SCR.Execute(path(".target.mkdir"), tmpdir)

      Profile.Save(Ops.add(tmpdir, "/base_profile.xml")) if base == :current


      error = false
      skip = false
      Builtins.foreach(selected_profiles) do |c|
        pl = Builtins.filter(AutoinstClass.confs) do |cc|
          Ops.get_string(cc, "name", "") == Ops.get_string(c, "profile", "") &&
            Ops.get_string(cc, "class", "yyy") ==
              Ops.get_string(c, "class", "xxx")
        end
        profile = Ops.get_map(pl, 0, {})
        if base == :empty && !skip
          Builtins.y2milestone("Working on profile: %1", profile)
          SCR.Execute(
            path(".target.bash"),
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(
                      Ops.add(
                        Ops.add(Ops.add("cp ", AutoinstConfig.classDir), "/"),
                        Ops.get_string(profile, "class", "")
                      ),
                      "/"
                    ),
                    Ops.get_string(profile, "name", "")
                  ),
                  "  "
                ),
                tmpdir
              ),
              "/base_profile.xml"
            )
          )
          skip = true
        else
          Builtins.y2milestone("Working on profile: %1", profile)
          base_text = "empty control file"
          base_text = "current control file" if base != :empty

          if Ops.get_string(profile, "name", "") != "" && !error
            Popup.ShowFeedback(
              Builtins.sformat(
                "Merging %1 (%2) with %3 ....",
                Ops.get_string(profile, "name", ""),
                Ops.get_string(profile, "class", ""),
                base_text
              ),
              ""
            )

            Builtins.y2milestone(
              "Merging %1 with %2....",
              Ops.get_string(profile, "name", ""),
              base_text
            )

            xsltret = AutoinstClass.MergeClasses(
              profile,
              Ops.add(tmpdir, "/base_profile.xml"),
              "result.xml"
            )
            if Ops.get_integer(xsltret, "exit", -1) != 0
              Popup.Error(
                Builtins.sformat(
                  _("Merge failed:\n %1"),
                  Ops.get_string(xsltret, "stderr", "error")
                )
              )
              error = true
            end
            XML_cleanup(
              Ops.add(tmpdir, "/result.xml"),
              Ops.add(tmpdir, "/base_profile.xml")
            )
          else
            error = true
          end
        end
      end


      if error
        Popup.ClearFeedback
        return false
      end

      # Backup file
      SCR.Execute(
        path(".target.bash"),
        Ops.add(
          Ops.add("cp ", tmpdir),
          "/result.xml /var/lib/autoinstall/tmp/autoinst_result.xml"
        )
      )

      Profile.ReadXML("/var/lib/autoinstall/tmp/autoinst_result.xml")
      SCR.Execute(
        path(".target.remove"),
        " /var/lib/autoinstall/tmp/autoinst_result.xml"
      )
      Popup.ClearFeedback

      true
    end


    # Merge Dialog
    # @return [Symbol]
    def MergeDialog
      Wizard.CreateDialog
      title = _("Merge Classes")
      profiles = {}

      _Combo = VBox()
      AutoinstClass.Files
      Builtins.foreach(AutoinstClass.confs) do |prof|
        _class = Ops.get_string(prof, "class", "Default")
        ui_list = Ops.get(profiles, _class, [])
        if Builtins.size(ui_list) == 0
          ui_list = Builtins.add(ui_list, Item(Id("none"), _("None")))
        end
        ui_list = Builtins.add(
          ui_list,
          Item(
            Id(Ops.get_string(prof, "name", "Unknown")),
            Ops.get_string(prof, "name", "Unknown")
          )
        )
        Ops.set(profiles, _class, ui_list)
      end


      if Ops.greater_than(Builtins.size(profiles), 0)
        Builtins.foreach(profiles) do |k, v|
          _Combo = Builtins.add(
            _Combo,
            HBox(
              HWeight(
                50,
                Left(ComboBox(Id(k), Opt(:hstretch, :autoShortcut), k, v))
              ),
              HWeight(50, Empty())
            )
          )
        end
      else
        _Combo = Left(Label(Id(:emptyclasses), _("No control files defined")))
      end


      contents = Top(
        Left(
          VBox(
            _Combo,
            VSpacing(),
            RadioButtonGroup(
              Id(:rbg),
              VBox(
                Left(
                  RadioButton(
                    Id(:empty),
                    _("&Merge with Empty Control File"),
                    true
                  )
                ),
                Left(
                  RadioButton(
                    Id(:current),
                    _("Merge with &Currently-Loaded Control File")
                  )
                )
              )
            ),
            PushButton(Id(:merge), _("Merge Cla&sses"))
          )
        )
      )


      help = _(
        "<p>If you have defined and created <b>\n" +
          "classes</b>, you will be able to merge them using this interface to create\n" +
          "a new <i>Profile</i>, which will contain information from every class\n" +
          "depending on the priority (order) set when\n" +
          "creating the classes.</P>\n"
      )

      help = Ops.add(
        help,
        _("<P>To merge the classes, an <b>XSLT</b>\nscript is used.</P>\n")
      )

      Wizard.SetContents(title, contents, help, true, true)

      Wizard.HideAbortButton
      widgets = [:merge, :empty, :current]

      Wizard.SetNextButton(:next, Label.FinishButton)
      Wizard.DisableNextButton

      ret = nil
      begin
        ret = UI.UserInput
        base = Convert.to_symbol(UI.QueryWidget(Id(:rbg), :CurrentButton))
        n = 0
        if ret == :merge
          selected_profiles = []
          Builtins.foreach(AutoinstClass.confs) do |prof|
            selected = UI.QueryWidget(
              Id(Ops.get_string(prof, "class", "")),
              :Value
            )
            if selected != nil
              n = Ops.add(n, 1) if selected != "none"
              selected_profiles = Builtins.add(
                selected_profiles,
                {
                  "order"   => GetClassOrder(Ops.get_string(prof, "class", "")),
                  "class"   => Ops.get_string(prof, "class", "none"),
                  "profile" => selected
                }
              )
            end
          end

          if n == 0
            min = 1

            min = 2 if base == :empty

            Popup.Error(
              Builtins.sformat(
                _("Select at least %1  configurations\nto perform a merge.\n"),
                min
              )
            )
            next
          end

          sorted_profiles = Builtins.sort(
            Builtins.filter(Builtins.toset(selected_profiles)) do |c|
              Ops.get_string(c, "profile", "") != "none"
            end
          ) do |x, y|
            Ops.less_than(
              Ops.get_integer(x, "order", 0),
              Ops.get_integer(y, "order", 0)
            )
          end
          Builtins.y2debug("Selected Profiles: %1", sorted_profiles)

          if Ops.greater_than(Builtins.size(sorted_profiles), 0)
            Builtins.y2milestone(
              "Calling merge with %1 (%2)",
              sorted_profiles,
              base
            )
            MergeAll(sorted_profiles, base)
          end

          Wizard.EnableNextButton
        end
      end until ret == :next || ret == :back

      Wizard.CloseDialog
      Convert.to_symbol(ret)
    end



    def classConfiguration
      title = _("Class Configuration")
      help = _(
        "<p>Choose one or more of the listed classes to which the current control\nfile should belong.</p>\n"
      )

      AutoinstClass.Files

      profiles = {}

      Builtins.foreach(AutoinstClass.confs) do |prof|
        _class = Ops.get_string(prof, "class", "default")
        ui_list = Ops.get(profiles, _class, [])
        if Builtins.size(ui_list) == 0
          ui_list = Builtins.add(ui_list, Item(Id("none"), _("None")))
        end
        ui_list = Builtins.add(
          ui_list,
          Item(
            Id(Ops.get_string(prof, "name", "Unknown")),
            Ops.get_string(prof, "name", "Unknown")
          )
        )
        Ops.set(profiles, _class, ui_list)
      end

      _Combo = VBox()

      if Ops.greater_than(Builtins.size(profiles), 0)
        Builtins.foreach(profiles) do |k, v|
          _Combo = Builtins.add(
            _Combo,
            Left(ComboBox(Id(k), Opt(:hstretch, :autoShortcut), k, v))
          )
        end
      else
        _Combo = Left(Label(Id(:emptyclasses), _("No profiles in this class")))
      end

      contents = Top(Left(VBox(_Combo)))


      Wizard.SetContents(title, contents, help, true, true)

      Wizard.HideAbortButton
      Wizard.SetNextButton(:next, Label.FinishButton)


      ret = nil
      _next = nil
      begin
        ret = UI.UserInput
        n = 0
        if ret == :next
          selected_profiles = []
          Builtins.foreach(AutoinstClass.confs) do |prof|
            selected = UI.QueryWidget(
              Id(Ops.get_string(prof, "class", "")),
              :Value
            )
            if selected != nil
              n = Ops.add(n, 1) if selected != "none"
              selected_profiles = Builtins.add(
                selected_profiles,
                {
                  "class_name"    => Ops.get_string(prof, "class", "none"),
                  "configuration" => selected
                }
              )
            end
          end

          if n == 0
            Popup.Error(_("Select at least one class configuration.\n"))
            ret = :again
            next
          end

          sorted_profiles = Builtins.filter(Builtins.toset(selected_profiles)) do |c|
            Ops.get_string(c, "configuration", "") != "none"
          end

          Builtins.y2debug("Selected Profiles: %1", sorted_profiles)
          AutoinstClass.profile_conf = deep_copy(sorted_profiles)
        end
      end until ret == :next || ret == :back
      Convert.to_symbol(ret)
    end
  end
end
