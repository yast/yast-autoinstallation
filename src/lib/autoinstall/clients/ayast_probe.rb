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

Yast.import "UI"
Yast.import "Stage"
Yast.import "AutoInstallRules"
Yast.import "Label"
require "y2storage"

module Y2Autoinstall
  module Clients
    class AyastProbe
      include Yast::UIShortcuts

      # Client entry point
      def main
        Yast::Stage.Set("initial")
        Yast::AutoInstallRules.ProbeRules

        Yast::UI.OpenDialog(
          Opt(:defaultsize),
          VBox(RichText(content), PushButton(Opt(:default), Yast::Label.OKButton))
        )
        Yast::UI.UserInput
        Yast::UI.CloseDialog

        nil
      end

      # Content
      #
      # @return [String] Dialog's content
      def content
        text = autoinstall_rules_content
        text << "<br>"
        text << storage_data_content
      end

    private

      # Builds a HTML table for a given hash
      #
      # Keys will be sorted in alphabetical order.
      #
      # @param rows [Hash<String,String>] Keys/values to show in the table
      # @return [String] HTML representation
      def table(rows)
        content = rows.keys.sort.map do |key|
          "<tr><td>#{key}</td><td> = </td><td>#{rows[key]}<br></td></tr>"
        end
        content.join("\n")
      end

      # @return [Array<Symbol>] AutoInstallRules to shown
      RULES = [
        :installed_product,
        :installed_product_version,
        :hostname,
        :hostaddress,
        :network,
        :domain,
        :efi,
        :arch,
        :karch,
        :product,
        :product_vendor,
        :board,
        :memsize,
        :totaldisk,
        :hostid,
        :mac,
        :linux,
        :others,
        :xserver
      ].freeze

      # Retrieves AutoinstallRules data
      #
      # @return [Hash<String,String>]
      def autoinstall_rules_data
        RULES.each_with_object({}) do |rule, hsh|
          value = Yast::AutoInstallRules.public_send(rule)
          hsh[rule] = value
        end
      end

      # Returns content for autoinstall rules section
      #
      # @return [String] Section content
      def autoinstall_rules_content
        "<h1>Keys for rules</h1>#{table(autoinstall_rules_data)}"
      end

      # Retrieves storage data
      #
      # Only disk devices are considered.
      #
      # @return [Hash<String,Hash>] Storage data indexed by device kernel name
      def storage_data
        return @storage_data if @storage_data

        devicegraph = Y2Storage::StorageManager.instance.probed

        @storage_data = devicegraph.disk_devices.each_with_object({}) do |device, data|
          hsh = Y2Storage::AutoinstProfile::SkipListValue.new(device).to_hash
          data[hsh[:device]] = hsh
        end
      end

      # Returns content for storage data section
      #
      # @return [String] Section content
      def storage_data_content
        text = "<h1>Storage Data</h1>"
        storage_data.keys.sort.each do |name|
          text << "<h2>#{name}</h2>"
          text << table(storage_data[name])
        end
        text
      end
    end
  end
end
