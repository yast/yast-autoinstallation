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
require "autoinstall/entries/registry"

module Y2Autoinstallation
  # This class holds the result of importing an entry
  #
  # @see Importer#import_entry
  class ImportResult
    # @return [Array<String>] List of imported sections
    attr_reader :sections

    # @param sections [Array<String>] List of imported sections
    # @param result [Boolean,nil] Result of the import process
    def initialize(sections, result)
      @sections = sections
      @result = result
    end

    # Whether the import process was successful
    #
    # This method considers `false` as the only failing value.
    def success?
      @result != false
    end
  end

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
        # Generic sections are handled by AutoYast itself and not mentioned
        # in any desktop or clients/*_auto.rb file.
        if managed.include?(name) || GENERIC_PROFILE_SECTIONS.include?(name)
          false
        else
          # Sections which are not handled in any desktop file but the
          # corresponding clients/*_auto.rb file is available.
          # e.g. user_defaults, report, general, files, scripts
          !Yast::WFM.ClientExists("#{name}_auto")
        end
      end
    end

    # Returns list of all profile sections from the profile that are
    # obsolete, e.g., we do not support them anymore.
    #
    # @return [Array<String>] of unsupported profile sections
    def obsolete_sections
      unhandled_sections & OBSOLETE_PROFILE_SECTIONS
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

    # Import just sections for given entry
    # @param entry [String | Entries::Description] to import
    # @return [ImportResult] Import result
    def import_entry(entry)
      res = []

      description = if entry.is_a?(Entries::Description)
        entry
      else
        registry.descriptions.find { |d| [d.module_name, d.resource_name].include?(entry) }
      end

      if description
        data = if description.managed_keys.size == 1
          resource = description.managed_keys.first
          if profile.key?(resource)
            res << resource
            profile[description.managed_keys.first]
          else
            key = description.aliases.find { |a| profile.key?(a) }
            return ImportResult.new(res, nil) unless key

            res << key
            profile[key]
          end
        else # for multiple section prepare profile
          selection = profile.select { |k, _| description.managed_keys.include?(k) }
          res.concat(selection.keys)
          selection
        end

        success = Yast::WFM.CallFunction(description.client_name, ["Import", data]) if data
      else
        raise "Unknown entry #{entry}" unless Yast::WFM.ClientExists("#{entry}_auto")

        data = profile[entry]
        if data
          success = Yast::WFM.CallFunction("#{entry}_auto", ["Import", data])
          res << entry
        end
      end

      ImportResult.new(res, success)
    end

  private

    attr_reader :profile

    def registry
      Entries::Registry.instance
    end

    # All these sections are handled by AutoYaST (or Installer) itself,
    # it doesn't use any external AutoYaST client for them
    GENERIC_PROFILE_SECTIONS = [
      # AutoYaST has its own partitioning
      "partitioning",
      "partitioning_advanced",
      # AutoYaST has its Preboot Execution Environment configuration
      "pxe",
      # Flags for setting the solver while the upgrade process with AutoYaST
      "upgrade",
      # Flags for controlling the update backups (see Installation module)
      "backup",
      # init section used by Kickstart and to pass additional arguments
      # to Linuxrc (bsc#962526)
      "init"
    ].freeze
    private_constant :GENERIC_PROFILE_SECTIONS

    # Dropped YaST modules that used to provide AutoYaST functionality
    # bsc#925381
    OBSOLETE_PROFILE_SECTIONS = [
      # FATE#316185: Drop YaST AutoFS module
      "autofs",
      # FATE#308682: Drop yast2-backup and yast2-restore modules
      "restore",
      "sshd",
      # Defined in SUSE Manager but will not be used anymore. (bnc#955878)
      "cobbler",
      # FATE#323373 drop xinetd from distro and yast2-inetd
      "inetd",
      # FATE#319119 drop yast2-ca-manament
      "ca_mgm"
    ].freeze
    private_constant :OBSOLETE_PROFILE_SECTIONS
  end
end
