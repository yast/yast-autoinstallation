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

require "autoinstall/entries/registry"

module Y2Autoinstallation
  # Worker class that handles importing of profile section using info from {Entries::Description}.
  # Its ability is beside calling import on auto client also detecting unhandled
  # or obsolete sections.
  class Importer
    # @param profile [Hash] profile to work with
    def initialize(profile)
      @profile = profile
    end

    # Returns list of all profile sections from the current profile, including
    # unsupported ones, that do not have any handler (AutoYaST client) assigned
    # at the current system and are not handled by AutoYaST itself.
    #
    # @return [Array<String>] of unknown profile sections
    def unhandled_sections
      managed = registry.descriptions.map(&:managed_keys).flatten

      profile.keys.select do |name|
        if managed.include?(name)
          false
        # Generic sections are handled by AutoYast itself and not mentioned
        # in any desktop or clients/*_auto.rb file.
        elsif Yast::ProfileClass::GENERIC_PROFILE_SECTIONS.include?(name)
          false
        else
          # Sections which are not handled in any desktop file but the
          # corresponding clients/*_auto.rb file is available.
          # e.g. user_defaults, report, general, files, scripts
          Yast::WFM.ClientExists("#{name}_auto")
        end
      end
    end

    # Returns list of all profile sections from the profile that are
    # obsolete, e.g., we do not support them anymore.
    #
    # @return [Array<String>] of unsupported profile sections
    def obsolete_sections
      unhandled_sections & Yast::ProfileClass::OBSOLETE_PROFILE_SECTIONS
    end

    # Imports profile by calling respective auto clients
    def import_sections
      registry.descriptions.each do |description|
        # just one section to manage, so check also aliases
        data = if description.managed_keys.size == 1
          if profile.key?(description.managed_keys.first)
            profile[description.managed_keys.first]
          else
            key = description.aliases.find { |a| profile.key?(a) }
            next unless key

            profile[key]
          end
        else # for multiple section prepare profile
          profile.select { |k, _| description.managed_keys.include?(k) }
        end

        Yast::WFM.CallFunction(description.client_name, ["Import", data]) if data
      end
    end

    # Import just keys for given entry
    # @param entry [String | Entries::Description] to import
    # @return [Array<String>] keys that are imported
    def import_entry(entry)
      res = []

      description = if entry.is_a?(Entries::Description)
        entry
      else
        registry.descriptions.find { |d| d.resource_name == entry }
      end

      if description
        data = if description.managed_keys.size == 1
          resource = description.managed_keys.first
          if profile.key?(resource)
            res << resource
            profile[description.managed_keys.first]
          else
            key = description.aliases.find { |a| profile.key?(a) }
            return res unless key

            res << key
            profile[key]
          end
        else # for multiple section prepare profile
          selection = profile.select { |k, _| description.managed_keys.include?(k) }
          res.concat(selection.keys)
          selection
        end

        Yast::WFM.CallFunction(description.client_name, ["Import", data]) if data
      else
        raise "Unknown entry #{entry}" unless WFM.ClientExists("#{entry}_auto")

        data = profile[entry]
        if data
          Yast::WFM.CallFunction("#{entry}_auto", ["Import", data])
          res << entry
        end
      end

      res
    end

  private

    attr_reader :profile

    def registry
      Entries::Registry.instance
    end
  end
end
