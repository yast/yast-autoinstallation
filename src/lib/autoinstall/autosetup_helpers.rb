# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

require "y2storage"
require "autoinstall/activate_callbacks"

module Y2Autoinstallation
  # This module defines some methods that are used in {Yast::InstAutosetupClient}
  # and {Yast::InstAutosetupUpgradeClient} clients. These clients need to be rewritten
  # but, for the time being, this is the easiest way to share code between them.
  module AutosetupHelpers
    # Activate and probe storage
    def probe_storage
      Y2Storage::StorageManager.instance.activate(Y2Autoinstallation::ActivateCallbacks.new)
      Y2Storage::StorageManager.instance.probe
    end

    # Read modified profile
    #
    # When a profile is found at /tmp/profile/modified.xml, it will replace
    # the current loaded profile. The original autoinst.xml file will be replaced
    # by modified.xml (a backup will be kept as pre-autoinst.xml).
    #
    # @return [Symbol] :abort if profile could not be read; :found when it was loaded;
    #   :not_found if it does not exist
    def readModified
      if Yast::SCR.Read(path(".target.size"), Yast::AutoinstConfig.modified_profile) <= 0
        return :not_found
      end

      if !Yast::Profile.ReadXML(Yast::AutoinstConfig.modified_profile) ||
          Yast::Profile.current == {}
        Yast::Popup.Error(
          _(
            "Error while parsing the control file.\n" +
            "Check the log files for more details or fix the\n" +
            "control file and try again.\n"
          )
        )
        return :abort
      end

      backup_autoinst
      update_autoinst
      @modified_profile = true
      :found
    end

    # Determine whether the profile was modified
    #
    # @return [Boolean] true if it was modified; false otherwise.
    def modified_profile?
      !!@modified_profile
    end

  private

    # Backup AutoYaST profile
    #
    # Copies autoinst.xml to pre-autoinst.xml.
    def backup_autoinst
      cpcmd = format(
        "mv %s %s",
        File.join(Yast::AutoinstConfig.profile_dir, "autoinst.xml"),
        File.join(Yast::AutoinstConfig.profile_dir, "pre-autoinst.xml")
      )
      log.info("copy original profile: #{cpcmd}")
      Yast::SCR.Execute(path(".target.bash"), cpcmd)
    end

    # Update AutoYaST profile
    #
    # Replaces autoinst.xml by modified.xml.
    def update_autoinst
      cpcmd = format(
        "mv %s %s",
        Yast::AutoinstConfig.modified_profile,
        File.join(Yast::AutoinstConfig.profile_dir, "autoinst.xml")
      )
      log.info("moving modified profile: #{cpcmd}")
      Yast::SCR.Execute(path(".target.bash"), cpcmd)
    end
  end
end
