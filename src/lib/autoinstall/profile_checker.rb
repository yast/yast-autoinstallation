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
require "yast2/popup"

Yast.import "AutoInstall"
Yast.import "AutoinstConfig"
Yast.import "AutoinstScripts"
Yast.import "Mode"
Yast.import "Popup"
Yast.import "ProfileLocation"

module Y2Autoinstallation
  class ProfileChecker
    include Yast::I18n
    include Yast::Logger

    def initialize(filename, import_all:, run_scripts:, target_file:)
      textdomain "autoinst"

      @filename = filename
      @import_all = import_all
      @run_scripts = run_scripts
      @target_file = target_file
    end

    def check
      Yast::Mode.SetUI("dialog") # check profile use UI and not cmdline

      Yast::Popup.Feedback(_("Obtaining Profile"),
        _("Fetching and generating final AutoYaST profile")) do
        Yast::AutoinstConfig.ParseCmdLine(path)
        res = Yast::ProfileLocation.Process
        return res unless res
      end

      # This is not problematic from security POV as it is own home,
      # so another user cannot create malicious link
      target_file = ::File.expand_path(@target_file)
      ::FileUtils.cp(Yast::AutoinstConfig.xml_tmpfile, target_file)
      return false unless import_profile(target_file)

      res = run_scripts(target_file)
      Yast2::Popup.show("Resulting autoyast profile is at #{target_file}")

      res
    end

  private

    # compute path that can be passed to parsing
    def path
      path = @filename

      if path !~ /^[a-zA-Z0-9]+:\//
        path = File.join(Dir.pwd, path) unless path.start_with?("/")
        path = "file://#{path}"
      end

      path
    end

    # Reads and imports a profile
    #
    # @param filename [String] Profile path
    # @return [Boolean] if import does not find any issue
    def import_profile(filename)
      return true unless @import_all

      if !Yast::Profile.ReadXML(filename)
        Yast2::Popup.show(
          _(
            "Error while parsing the control file.\n" \
              "Check the log files for more details or fix the\n" \
              "AutoYaST profile and try again.\n"
          ), headline: :error
        )
      end
      Yast::Popup.Feedback(
        _("Reading configuration data"),
        _("This may take a while")
      ) do
        Y2Autoinstallation::Importer.new(Yast::Profile.current).import_sections
      end

      Yast::AutoInstall.valid_imported_values
    end

    SCRIPTS_PARAMS = [
      ["pre-scripts", true],
      ["postpartitioning-scripts", true],
      ["chroot-scripts", true],
      ["chroot-scripts", false],
      ["post-scripts", false],
      ["init-scripts", false]
    ].freeze
    # run all scripts defined in profile
    # @return [Boolean] true if all scripts works
    def run_scripts(filename)
      return true unless @run_scripts

      res = true

      Yast::Popup.Feedback(_("Executing Scripts"),
        _("Trying to run all scripts in AutoYaST profile.")) do
        log.info "Running scripts"
        mode = Yast::Mode.mode
        Yast::Mode.SetMode("autoinstallation") # to run scripts we need autoinst mode
        # we need to import at least scripts if not all of them are imported
        if !@import_all
          Yast::Profile.ReadXML(filename)
          Yast::AutoinstScripts.Import(Yast::Profile.current.fetch("scripts", {}))
          log.info "importing scripts #{Yast::Profile.current.fetch("scripts", {})}"
        end
        SCRIPTS_PARAMS.each do |type, special|
          # pre-scripts has some expectations where profile lives
          if type == "pre-scripts"
            # clean previous content
            if File.exist?(Yast::AutoinstConfig.profile_dir)
              ::FileUtils.rm_r(Yast::AutoinstConfig.profile_dir)
            end
            ::FileUtils.mkdir_p(Yast::AutoinstConfig.profile_dir)
            ::FileUtils.cp(filename, Yast::AutoinstConfig.profile_path)
          end
          res = Yast::AutoinstScripts.Write(type, special) && res
          # pre scripts can do modification of profile, so reload it
          if type == "pre-scripts" && File.exist?(Yast::AutoinstConfig.modified_profile)
            ::FileUtils.cp(Yast::AutoinstConfig.modified_profile, filename)
            return false unless import_profile(filename)
          end
        end
        Yast::Mode.SetMode(mode) # restore previous mode
      end

      res
    end
  end
end
