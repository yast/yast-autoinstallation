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

Yast.import "Mode"
Yast.import "AutoinstConfig"
Yast.import "ProfileLocation"

module Y2Autoinstallation
  class ProfileChecker
    def initialize(filename, import_all:, run_scripts:, target_file:)
      @filename = filename
      @import_all = import_all
      @run_scripts = run_scripts
      @target_file = target_file
    end

    def check
      Yast::Mode.SetUI("dialog") # check profile use UI and not cmdline

      path = @filename
      if path !~ /^[a-zA-Z0-9]+:\//
        path = File.join(Dir.pwd, path) unless path.start_with?("/")
        path = "file://#{path}"
      end

      Yast::AutoinstConfig.ParseCmdLine(path)
      res = Yast::ProfileLocation.Process
      return res unless res

      # This is not problematic from security POV as it is own home,
      # so another user cannot create malicious link
      target_file = ::File.expand_path(@target_file)
      ::FileUtils.cp(Yast::AutoinstConfig.xml_tmpfile, target_file)
      import_profile(target_file) if @import_all
      run_scripts(target_file)
      Yast2::Popup.show("Resulting autoyast profile is at #{target_file}")

      res

    end

  private
    # Reads and imports a profile
    #
    # @param filename [String] Profile path
    def import_profile(filename)
      if !Yast::Profile.ReadXML(filename)
        Yast::Popup.Error(
          _(
            "Error while parsing the control file.\n" \
              "Check the log files for more details or fix the\n" \
              "AutoYaST profile and try again.\n"
          )
        )
      end
      Yast::Popup.ShowFeedback(
        _("Reading configuration data"),
        _("This may take a while")
      )
      Y2Autoinstallation::Importer.new(Profile.current).import_sections
      Yast::Popup.ClearFeedback
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
      log.info "Running scripts"
      mode = Yast::Mode.mode
      Yast::Mode.SetMode("autoinstallation") # to run scripts we need autoinst mode
      res = true
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
          import_profile(filename) if @import_all
        end
      end
      Yast::Mode.SetMode(mode) # restore previous mode

      res
    end

  end
end
