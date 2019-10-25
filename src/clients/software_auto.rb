# encoding: utf-8

# File:	clients/autoinst_software.ycp
# Package:	Autoinstallation Configuration System
# Authors:	Anas Nashif (nashif@suse.de)
# Summary:	Handle Package selections and packages
#
# $Id$
module Yast
  class SoftwareAutoClient < Client
    def main
      Yast.import "Pkg"
      Yast.import "UI"

      textdomain "autoinst"

      Yast.import "Wizard"
      Yast.import "Summary"
      Yast.import "Report"
      Yast.import "AutoinstConfig"
      Yast.import "AutoinstSoftware"
      Yast.import "Label"
      Yast.import "PackageAI"
      Yast.import "AutoInstall"
      Yast.import "SourceManager"
      Yast.import "PackagesUI"
      Yast.import "Popup"

      Yast.include self, "autoinstall/dialogs.rb"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)


      # create a  summary

      if @func == "Summary"
        @ret = AutoinstSoftware.Summary
      elsif @func == "Import"
        @ret = AutoinstSoftware.Import(@param)
      elsif @func == "Read"
        # use the previously saved software selection if defined (bsc#956325)
        @ret = AutoinstSoftware.SavedPackageSelection || AutoinstSoftware.Read
      elsif @func == "Reset"
        AutoinstSoftware.Import({})
        @ret = {}
      elsif @func == "Change"
        @ret = packageSelector
      elsif @func == "GetModified"
        @ret = AutoinstSoftware.GetModified || PackageAI.GetModified
      elsif @func == "SetModified"
        AutoinstSoftware.SetModified
        @ret = true
      elsif @func == "Export"
        @ret = AutoinstSoftware.Export
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("Software auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # Finish
    end

    # Select packages
    # @return [Symbol]
    def packageSelector
      language = UI.GetLanguage(true)

      title = _("Software Selection")
      helptext = _(
        "<p>\n" +
          "Select one of the following <b>base</b> selections and click <i>Detailed<i> to add\n" +
          "more <b>add-on</b> selections and packages.\n" +
          "</p>\n"
      )
      #Pkg::TargetFinish ();
      Pkg.CallbackAcceptFileWithoutChecksum(
        fun_ref(
          AutoInstall.method(:callbackTrue_boolean_string),
          "boolean (string)"
        )
      )
      Pkg.CallbackAcceptUnsignedFile(
        fun_ref(
          AutoInstall.method(:callbackTrue_boolean_string_integer),
          "boolean (string, integer)"
        )
      )

      tmpdir = Convert.to_string(SCR.Read(path(".target.tmpdir")))
      # AutoinstSoftware::pmInit();

      #string mainRepo = "http://10.10.0.162/SLES11/DVD1/";
      #string mainRepo = "ftp://10.10.0.100/install/SLP/openSUSE-11.2/x86_64/DVD1/";
      mainRepo = AutoinstSoftware.instsource
      contents = VBox(
        HBox(
          VBox(
            TextEntry(
              Id(:location),
              Opt(:notify),
              _(
                "Location of the installation source (like http://myhost/11.3/DVD1/)"
              ),
              mainRepo
            ),
            CheckBox(
              Id(:localSource),
              Opt(:notify),
              _(
                "The inst-source of this system (you can't create images if you choose this)"
              ),
              mainRepo == ""
            )
          )
        ),
        HBox(PushButton(Id(:ok), Label.OKButton), PushButton(Id(:abort), Label.AbortButton))
      )
      UI.OpenDialog(Opt(:decorated), contents)
      UI.ChangeWidget(Id(:location), :Enabled, mainRepo != "")
      okay = false
      begin
        ret = nil
        if Ops.greater_than(
            Builtins.size(
              Convert.to_string(UI.QueryWidget(Id(:location), :Value))
            ),
            0
          )
          UI.ChangeWidget(Id(:localSource), :Enabled, false)
        else
          UI.ChangeWidget(Id(:localSource), :Enabled, true)
        end
        ret = UI.UserInput
        if ret == :ok
          if Convert.to_boolean(UI.QueryWidget(Id(:localSource), :Value))
            Pkg.TargetInit("/", false)
            okay = true
          else
            Pkg.SourceFinishAll
            mainRepo = Convert.to_string(UI.QueryWidget(Id(:location), :Value))
            Pkg.TargetInit(tmpdir, false)
            if SourceManager.createSource(mainRepo) == :ok
              okay = true
            else
              Popup.Error(_("using that installation source failed"))
            end
          end
        elsif ret == :abort
          UI.CloseDialog
          return :back
        elsif ret == :localSource
          localSource = Convert.to_boolean(
            UI.QueryWidget(Id(:localSource), :Value)
          )
          UI.ChangeWidget(Id(:location), :Enabled, !localSource)
          UI.ChangeWidget(Id(:location), :Value, "") if localSource
        end
      end while !okay
      UI.CloseDialog
      AutoinstSoftware.instsource = mainRepo


      Pkg.SourceStartManager(true)

      Wizard.CreateDialog
      Wizard.SetDesktopIcon("software")

      Wizard.SetContents(
        title,
        HVCenter(Label(_("Reading package database..."))),
        helptext,
        false,
        true
      )
      patterns = Pkg.ResolvableProperties("", :pattern, "")
      Builtins.y2milestone("available patterns %1", patterns)
      #        Pkg::TargetInit("/tmp", false); // don't copy the list of really installed packages (#231687)
      # Construct a box with radiobuttons for each software base configuration
      baseconfs_box = VBox()

      # sort available_base_selections by order
      # $[ "order" : [ "name", "summary" ], .... ]

      if patterns != []
        @ret = :again
        Pkg.PkgReset
        Builtins.foreach(AutoinstSoftware.patterns) do |pattern|
          Pkg.ResolvableInstall(pattern, :pattern)
        end

        if Ops.greater_than(Builtins.size(PackageAI.toinstall), 0)
          Builtins.foreach(PackageAI.toinstall) do |p|
            Builtins.y2milestone(
              "selecting package for installation: %1 -> %2",
              p,
              Pkg.PkgInstall(p)
            )
          end
        end
        if Ops.greater_than(Builtins.size(PackageAI.toremove), 0)
          Builtins.foreach(PackageAI.toremove) do |p|
            Builtins.y2milestone(
              "deselecting package for installation: %1 -> %2",
              p,
              Pkg.PkgTaboo(p)
            )
          end
        end
        while @ret == :again
          @ret = PackagesUI.RunPackageSelector({ "mode" => :searchMode })

          @ret = :next if @ret == :accept
        end
      end
      allpacs = Pkg.GetPackages(:selected, true)
      Builtins.y2milestone(
        "All packages: %1 ( %2 )",
        allpacs,
        Builtins.size(allpacs)
      )

      seladd = []
      selbase = []
      patadd = []
      if @ret != :back
        Builtins.y2milestone(
          "available patterns %1",
          Pkg.ResolvableProperties("", :pattern, "")
        )
        Builtins.foreach(Pkg.ResolvableProperties("", :pattern, "")) do |p|
          if Ops.get_symbol(p, "status", :nothing) == :selected
            patadd = Builtins.add(patadd, Ops.get_string(p, "name", ""))
          end
        end
      else
        patadd = deep_copy(AutoinstSoftware.patterns)
      end



      PackageAI.toinstall = Pkg.FilterPackages(false, true, true, true)
      PackageAI.toremove = Pkg.GetPackages(:taboo, true)
      AutoinstSoftware.patterns = Convert.convert(
        Builtins.union(patadd, patadd),
        :from => "list",
        :to   => "list <string>"
      ) # FIXME: why are there double entries sometimes?

      Wizard.CloseDialog
      Convert.to_symbol(@ret)
    end
  end
end

Yast::SoftwareAutoClient.new.main
