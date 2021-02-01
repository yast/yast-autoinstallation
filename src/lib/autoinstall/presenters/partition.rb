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
require "autoinstall/presenters/section"

module Y2Autoinstallation
  module Presenters
    # Presenter for Y2Storage::AutoinstProfile::PartitionSection
    #
    # In an AutoYaST profile, a <partition> section is used to define a partition or a logical
    # volume. In addition, for <drive> sections with disklabel=none, a <partition> section is used
    # to define how to use the device indicated by the <drive> section.
    class Partition < Section
      include Yast::I18n

      # Constructor
      #
      # @param section [Y2Storage::AutoinstProfile::PartitionSection] partition section
      # @param drive [Drive] presenter of the parent drive section
      def initialize(section, drive)
        textdomain "autoinst"
        super(section)
        @drive_presenter = drive
      end

      # Determines the usage of the device described by the partition section
      #
      # @return [Symbol]
      def usage
        if raid_name
          :raid
        elsif lvm_group
          :lvm_pv
        elsif filesystem || mounted?
          :filesystem
        elsif bcache_backing_for
          :bcache_backing
        elsif btrfs_name
          :btrfs_member
        else
          :none
        end
      end

      # Localized label to represent this section in the UI
      #
      # @return [String]
      def ui_label
        parts = { device_type: device_type_label, usage: usage_label, name: device_name }
        if device_name
          # TRANSLATORS: this is how a <Partition> section of the AutoYaST profile is represented
          # in the UI. All words are placeholders and should NOT be translated, use this string
          # only to adapt the layout of the information.
          Kernel.format("%{device_type}: %{name}, %{usage}", parts)
        else
          # TRANSLATORS: this is how a <Partition> section of the AutoYaST profile is represented
          # in the UI. %{device_type} and %{usage} are placeholders and should NOT be translated,
          # use this string only to adapt the layout of the information.
          Kernel.format("%{device_type}: %{usage}", parts)
        end
      end

      # Type of the parent drive section
      #
      # @return [DriveType]
      def drive_type
        drive_presenter.type
      end

      # String representation of #fstab_options
      #
      # The field is actually called fstopt in the AutoYaST xml and treated like a plain string,
      # so this method provides a more direct communication between the profile and the current
      # UI (which also uses a plain InputField).
      #
      # @return [String]
      def fstopt
        fstab_options&.join(",")
      end

      # Whether the section is an LVM Logical Volume
      #
      # @return [Boolean] true when belongs to an LVM drive; false otherwise
      def logical_volume?
        drive_type.to_sym == :CT_LVM
      end

      # Whether this belongs to a drive that is only used to represent filesystems
      #
      # @return [Boolean]
      def filesystem_drive?
        [:CT_NFS, :CT_TMPFS, :CT_BTRFS].include?(drive_type.to_sym)
      end

      # Whether this represents a device that only exists in the system when it's mounted
      #
      # @return [Boolean] false if this is no backed (directly or indirectly) by block devices
      def fstab_based?
        [:CT_NFS, :CT_TMPFS].include?(drive_type.to_sym)
      end

      # Values to suggest for bcache devices fields
      #
      # @return [Array<String>]
      def available_bcaches
        devices_for(type: :CT_BCACHE)
      end

      # Values to suggest for Btrfs devices fields
      #
      # @return [Array<String>]
      def available_btrfs
        devices_for(type: :CT_BTRFS)
      end

      # Values to suggest for the lvm_group field
      #
      # @return [Array<String>]
      def available_lvm_groups
        devices_for(type: :CT_LVM).map { |n| n.delete_prefix("/dev/") }
      end

    private

      # @return [Drive] presenter of the parent drive section
      attr_reader :drive_presenter

      # Parent drive section
      #
      # @return [Y2Storage::AutoinstProfile::DriveSection]
      def drive
        drive_presenter.section
      end

      # @return [String, nil]
      def device_name
        return nil unless device_type == :lv && lv_name && !lv_name.empty?

        lv_name
      end

      # Return available devices names of given type
      #
      # @param type [Symbol] the drive type to look for
      # @return [Array<String>] available devices names
      def devices_for(type:)
        drives = drive.parent.drives.select { |d| d.type == type }
        drives.map(&:device).compact
      end

      # Whether the partition has a mount point
      #
      # @return [Boolean] true when there is a not empty mount point; false otherwise
      def mounted?
        mount && !mount.empty?
      end

      # @see #ui_label
      #
      # @return [String]
      def device_type_label
        case device_type
        when :partition
          # TRANSLATORS: this refers to the name of a section in the AutoYaST
          # profile, so it's likely not a good idea to translate the term
          _("Partition")
        when :drive
          # TRANSLATORS: these are names of sections in the AutoYaST profile,
          # so it's likely not a good idea to translate the terms
          _("Partition (Drive)")
        when :lv
          # TRANSLATORS: 'Partition' is the name of a section in the AutoYaST
          # profile, so it's likely not a good idea to translate the term
          _("Partition (LV)")
        when :filesystem
          # TRANSLATORS: 'Partition' is the name of a section in the AutoYaST
          # profile, so it's likely not a good idea to translate the term
          _("Partition (File System)")
        else
          # TRANSLATORS: 'Partition' is the name of a section in the AutoYaST
          # profile, so it's likely not a good idea to translate the term
          _("Partition (Unused)")
        end
      end

      # @see #ui_label
      def usage_label
        case usage
        when :filesystem
          if mounted?
            mount
          else
            _("Not Mounted")
          end
        when :raid
          # TRANSLATORS: %s is a placeholder for the name of a RAID
          Kernel.format(_("Part of %s"), raid_name)
        when :lvm_pv
          # TRANSLATORS: %s is a placeholder for the name of an LVM volume group
          Kernel.format(_("Part of %s"), lvm_group)
        when :bcache_backing
          # TRANSLATORS: %s is a placeholder for the name of a bcache device
          Kernel.format(_("Backing for %s"), bcache_backing_for)
        when :btrfs_member
          # TRANSLATORS: %s is a placeholder for the name of a Btrfs filesystem
          Kernel.format(_("Part of %s"), btrfs_name)
        when :none
          _("Not used")
        end
      end

      # Type of the device defined by the section
      #
      # @return [Symbol] :lv, :partition, :drive or :none
      def device_type
        return :lv if drive.type == :CT_LVM

        return device_type_no_partitions if drive.master_partition

        (drive.type == :CT_TMPFS) ? :filesystem : :partition
      end

      # @see #device_type
      def device_type_no_partitions
        return :drive if drive.master_partition == section

        :none
      end

      # @see Section#clean_section
      def clean_section(attrs)
        # "fstopt" is the right key to use as part of the hash received by
        # Y2Storage::AutoinstProfile::PartitionSection.init_from_hashes,
        # but the corresponding attribute in that class is called #fstab_options
        new_attrs =
          if attrs.include?("fstopt")
            attrs - ["fstopt"] + ["fstab_options"]
          else
            attrs
          end
        super(new_attrs)
      end
    end
  end
end
