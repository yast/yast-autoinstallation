# File:  include/autoinstall/helps.ycp
# Package:  Configuration of autoinstall
# Summary:  Help texts of all the dialogs
# Authors:  anas nashif <nashif@suse.de>
#
# $Id$
module Yast
  module AutoinstallHelpsInclude
    def initialize_autoinstall_helps(_include_target)
      textdomain "autoinst"

      # All helps are here
      @HELPS = {
        "valid"       => _("<p><b><big>Profile Validation</big></b><br>") +
          _(
            "<p>This tool uses <em>xmllint</em> to validate the profile against the DTD and\n" \
              "it checks for missing data. Some missing data might be intentional and any\n" \
              "reported errors can be ignored, for example, when creating classes.</p>\n"
          ) +
          _(
            "<p>Load a profile first. Otherwise an empty file\nis validated.</p>\n"
          ),
        "clone"       => _(
          "<p>This tool creates a reference profile by reading\n" \
            "information from this system. Select the resources to read from this system\n" \
            "in addition to the default resources, like partitioning and package selections.</p>\n"
        ),
        "drivedialog" => _("<p> Partition your hard disks... </p>") +
          _(
            "<p>The table to the right shows the partitions to create on the target system.\n</p>\n"
          ) +
          _("<p><b>Hard disks</b> are designated like this </p>") +
          _(
            "<tt>/dev/hda </tt>1st EIDE disk\n" \
              "<tt>/dev/hdb </tt>2nd EIDE disk\n" \
              "<tt>/dev/hdc </tt>3rd EIDE disk"
          ) +
          _("<p>etc.</p>") +
          _("<p>- or - </p>") +
          _(
            "<p><tt>/dev/sda </tt>1st SCSI disk\n" \
              "<tt>/dev/sdb </tt>2nd SCSI disk\n" \
              "<tt>/dev/sdc </tt>3rd SCSI disk</p>"
          ) +
          _(
            "If no partitions are defined and the specified drive is also\n" \
              "the drive where the root partition should reside, the following partitions are\n" \
              "created automatically:"
          ) +
          _(
            " <tt>/boot</tt>, <tt>swap</tt>, and a root partition <tt>/</tt>.\n" \
              "Sizes are calculated automatically.\n"
          ) +
          _("<p><b>Advanced Options</b></p>") +
          _(
            "By default, AutoYaST will create an extended partition and adds all new " \
              "partitions as logical devices. It is possible, however, to instruct AutoYaST " \
              "to create a certain partition as a primary partition or as extended partition. " \
              "Additionally, it is possible to specify the size of a partition using " \
              "sectors rather than size in MBytes."
          ) +
          _(
            "These options and other advanced options cannot be configured using this\n" \
              "interface.  Instead, add them manually to the control file.\n"
          ) +
          _(
            "<p>\n" \
              "For LVM and RAID setup, consult the documentation and add the configuration\n" \
              "to an existing control file. You can only create unformatted LVM " \
              "and RAID partitions as\n" \
              "a preparation.\n" \
              "</p>\n"
          )
      }

      # EOF
    end
  end
end
