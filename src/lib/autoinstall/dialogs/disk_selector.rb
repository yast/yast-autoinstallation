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

require "ui/dialog"
require "y2storage"

Yast.import "Label"
Yast.import "UI"

module Y2Autoinstallation
  module Dialogs
    # Ask the user for which device to use
    #
    # This dialog will be used by the partitioning section preprocessor (see
    # {Y2Autoinstallation::PartitioningPreprocessor}) in order to determine
    # which device to use for a given +<drive/>+ section.
    class DiskSelector < UI::Dialog
      # @return [Y2Storage::Devicegraph] Devicegraph used to find disks
      attr_reader :devicegraph
      # @return [Array<String>] Device names that should be omitted
      attr_reader :blacklist
      # @return [Integer] Drive section index
      attr_reader :drive_index

      # Constructor
      #
      # @param devicegraph [Y2Storage::Devicegraph] Devicegraph used to find disks.
      #   By default, the probed devicegraph is used.
      # @param drive_index [Integer] Drive section index.
      # @param blacklist   [Array<String>] Device names that should be omitted.
      #   These disks will be filtered out.
      def initialize(devicegraph = nil, drive_index: 1, blacklist: [])
        textdomain "autoinst"
        @devicegraph = devicegraph || Y2Storage::StorageManager.instance.probed
        @drive_index = drive_index
        @blacklist = blacklist
      end

      # Dialog content
      #
      # @return [Yast::Term] Dialog content
      # @see #disks_content
      # @see #empty_content
      def dialog_content
        options.empty? ? empty_content : disks_content
      end

      # Dialog content when some disks are available
      #
      # @return [Yast::Term] Dialog content
      def disks_content
        VBox(
          Heading(_("Disk Selection")),
          VSpacing(1),
          Label(help_text),
          VSpacing(1),
          RadioButtonGroup(
            Id(:options),
            VBox(*options)
          ),
          VSpacing(1),
          ButtonBox(*buttons)
        )
      end

      # Dialog content when no disks are found
      #
      # @return [Yast::Term]
      def empty_content
        VBox(
          Label(_("No disks found.")),
          ButtonBox(abort_button)
        )
      end

      # Handler for the `Continue` button
      def ok_handler
        finish_dialog(Yast::UI::QueryWidget(Id(:options), :Value))
      end

      # Handler for the `Abort` button
      def abort_handler
        finish_dialog(:abort)
      end

    protected

      # Returns a list of options containing available disks
      #
      # The first disk is preselected.
      #
      # @return [Array<Yast::Term>] List of options
      def options
        return @options if @options
        first_disk = disks.first
        @options = disks.each_with_index.map do |disk, idx|
          Left(RadioButton(Id(disk.name), "#{idx + 1}: #{label(disk)}", first_disk == disk))
        end
      end

      # Returns a list of available disks in the system
      #
      # Blacklisted disks are filtered out.
      #
      # @return [Array<Y2Storage::Device>] List of disks
      def disks
        @disks ||= devicegraph.disk_devices.reject do |disk|
          blacklist.include?(disk.name)
        end
      end

      # Dialog buttons
      #
      # @return [Array<Yast::Term>]
      def buttons
        [
          PushButton(Id(:ok), Opt(:okButton, :key_F10, :default), Yast::Label.ContinueButton),
          abort_button
        ]
      end

      # Abort button
      #
      # @return [Yast::Term]
      def abort_button
        PushButton(Id(:abort), Opt(:cancel_button, :key_F9), Yast::Label.AbortButton)
      end

      # Disk label to show in the list of options
      #
      # @param disk [Y2Storage::Device] Disk
      # @return [String] Label
      def label(disk)
        "#{disk.basename}, #{disk.hwinfo.model}"
      end

      # Help text
      def help_text
        # TRANSLATORS: %s will be replaced by a number
        _("All hard disks automatically detected on your system are shown here.\n" \
          "Please, select a hard disk to be used in the #%s drive section of the\n" \
          "given AutoYaST profile.") % drive_index
      end
    end
  end
end
