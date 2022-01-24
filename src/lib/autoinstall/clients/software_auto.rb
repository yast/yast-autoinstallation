# Copyright (c) [2021] SUSE LLC
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
require "y2packager/resolvable"

module Y2Autoinstallation
  module Clients
    class SoftwareAuto < Yast::Client
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
        Yast.import "PackagesProposal"
        Yast.import "AutoInstall"
        Yast.import "SourceManager"
        Yast.import "PackagesUI"
        Yast.import "Popup"

        Yast.include self, "autoinstall/dialogs.rb"

        @ret = nil
        @func = ""
        @param = {}

        # Check arguments
        if Yast::Ops.greater_than(Yast::Builtins.size(WFM.Args), 0) &&
            Yast::Ops.is_string?(WFM.Args(0))
          @func = Yast::Convert.to_string(WFM.Args(0))
          if Yast::Ops.greater_than(Yast::Builtins.size(WFM.Args), 1) &&
              Yast::Ops.is_map?(WFM.Args(1))
            @param = Yast::Convert.to_map(WFM.Args(1))
          end
        end
        Yast::Builtins.y2debug("func=%1", @func)
        Yast::Builtins.y2debug("param=%1", @param)

        # create a  summary

        if @func == "Summary"
          @ret = Yast::AutoinstSoftware.Summary
        elsif @func == "Import"
          @ret = Yast::AutoinstSoftware.Import(@param)
        elsif @func == "Read"
          # use the previously saved software selection if defined (bsc#956325)
          @ret = Yast::AutoinstSoftware.SavedPackageSelection || Yast::AutoinstSoftware.Read
        elsif @func == "Reset"
          Yast::AutoinstSoftware.Import({})
          @ret = {}
        elsif @func == "Change"
          @ret = packageSelector
        elsif @func == "GetModified"
          packages = Yast::PackagesProposal.GetResolvables("autoyast", :package) +
            Yast::PackagesProposal.GetTaboos("autoyast", :package)
          @ret = Yast::AutoinstSoftware.GetModified || !packages.empty?
        elsif @func == "SetModified"
          Yast::AutoinstSoftware.SetModified
          @ret = true
        elsif @func == "Export"
          @ret = Yast::AutoinstSoftware.Export
        else
          Yast::Builtins.y2error("unknown function: %1", @func)
          @ret = false
        end

        Yast::Builtins.y2debug("ret=%1", @ret)
        Yast::Builtins.y2milestone("Software auto finished")
        Yast::Builtins.y2milestone("----------------------------------------")

        deep_copy(@ret)

        # Finish
      end

      # Select packages
      # @return [Symbol]
      def packageSelector
        title = _("Software Selection")
        helptext = _(
          "<p>\n" \
          "Select one of the following <b>base</b> selections and click <i>Detailed<i> to add\n" \
          "more <b>add-on</b> selections and packages.\n" \
          "</p>\n"
        )
        # Yast::Pkg::TargetFinish ();
        Yast::Pkg.CallbackAcceptFileWithoutChecksum(
          fun_ref(
            Yast::AutoInstall.method(:callbackTrue_boolean_string),
            "boolean (string)"
          )
        )
        Yast::Pkg.CallbackAcceptUnsignedFile(
          fun_ref(
            Yast::AutoInstall.method(:callbackTrue_boolean_string_integer),
            "boolean (string, integer)"
          )
        )

        tmpdir = Yast::Convert.to_string(SCR.Read(path(".target.tmpdir")))

        mainRepo = Yast::AutoinstSoftware.instsource
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
          HBox(
            PushButton(Id(:ok), Yast::Label.OKButton),
            PushButton(Id(:abort), Yast::Label.AbortButton)
          )
        )
        UI.OpenDialog(Opt(:decorated), contents)
        UI.ChangeWidget(Id(:location), :Enabled, mainRepo != "")
        loop do
          if Yast::Ops.greater_than(
            Yast::Builtins.size(
              Yast::Convert.to_string(UI.QueryWidget(Id(:location), :Value))
            ),
            0
          )
            UI.ChangeWidget(Id(:localSource), :Enabled, false)
          else
            UI.ChangeWidget(Id(:localSource), :Enabled, true)
          end
          ret = UI.UserInput
          if ret == :ok
            if Yast::Convert.to_boolean(UI.QueryWidget(Id(:localSource), :Value))
              Yast::Pkg.TargetInit("/", false)
              break
            else
              Yast::Pkg.SourceFinishAll
              mainRepo = Yast::Convert.to_string(UI.QueryWidget(Id(:location), :Value))
              Yast::Pkg.TargetInit(tmpdir, false)
              if Yast::SourceManager.createSource(mainRepo) == :ok
                break
              else
                Yast::Popup.Error(_("using that installation source failed"))
              end
            end
          elsif ret == :abort
            UI.CloseDialog
            return :back
          elsif ret == :localSource
            localSource = Yast::Convert.to_boolean(
              UI.QueryWidget(Id(:localSource), :Value)
            )
            UI.ChangeWidget(Id(:location), :Enabled, !localSource)
            UI.ChangeWidget(Id(:location), :Value, "") if localSource
          end
        end
        UI.CloseDialog
        Yast::AutoinstSoftware.instsource = mainRepo

        Yast::Pkg.SourceStartManager(true)

        Yast::Wizard.CreateDialog
        Yast::Wizard.SetDesktopIcon("software")

        Yast::Wizard.SetContents(
          title,
          HVCenter(Label(_("Reading package database..."))),
          helptext,
          false,
          true
        )
        patterns = Y2Packager::Resolvable.find(kind: :pattern)
        Yast::Builtins.y2milestone("available patterns %1", patterns)
        # sort available_base_selections by order
        # $[ "order" : [ "name", "summary" ], .... ]

        if patterns != []
          @ret = :again
          Yast::Pkg.PkgReset
          Yast::Builtins.foreach(Yast::AutoinstSoftware.patterns) do |pattern|
            Yast::Pkg.ResolvableInstall(pattern, :pattern)
          end

          pkgs_to_install = Yast::PackagesProposal.GetResolvables("autoyast", :package)
          if Yast::Ops.greater_than(Yast::Builtins.size(pkgs_to_install), 0)
            Yast::Builtins.foreach(pkgs_to_install) do |p|
              Yast::Builtins.y2milestone(
                "selecting package for installation: %1 -> %2",
                p,
                Yast::Pkg.PkgInstall(p)
              )
            end
          end

          pkgs_to_remove = Yast::PackagesProposal.GetTaboos("autoyast", :package)
          if Yast::Ops.greater_than(Yast::Builtins.size(pkgs_to_remove), 0)
            Yast::Builtins.foreach(pkgs_to_remove) do |p|
              Yast::Builtins.y2milestone(
                "deselecting package for installation: %1 -> %2",
                p,
                Yast::Pkg.PkgTaboo(p)
              )
            end
          end
          while @ret == :again
            @ret = Yast::PackagesUI.RunPackageSelector("mode" => :searchMode)

            @ret = :next if @ret == :accept
          end
        end
        allpacs = Yast::Pkg.GetPackages(:selected, true)
        Yast::Builtins.y2milestone(
          "All packages: %1 ( %2 )",
          allpacs,
          Yast::Builtins.size(allpacs)
        )

        patadd = []
        if @ret != :back
          all_patterns = Y2Packager::Resolvable.find(
            kind: :pattern, status: :selected
          ).map(&:name)
          Yast::Builtins.y2milestone(
            "available patterns %1", all_patterns
          )
          patadd = all_patterns
        else
          patadd = deep_copy(Yast::AutoinstSoftware.patterns)
        end

        Yast::PackagesProposal.SetResolvables(
          "autoyast", :package, Yast::Pkg.FilterPackages(false, true, true, true)
        )
        Yast::PackagesProposal.SetTaboos(
          "autoyast", :package, Yast::Pkg.GetPackages(:taboo, true)
        )
        Yast::AutoinstSoftware.patterns = Yast::Convert.convert(
          Yast::Builtins.union(patadd, patadd),
          from: "list",
          to:   "list <string>"
        ) # FIXME: why are there double entries sometimes?

        Yast::Wizard.CloseDialog
        Yast::Convert.to_symbol(@ret)
      end
    end
  end
end
