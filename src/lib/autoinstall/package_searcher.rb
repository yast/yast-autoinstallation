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

Yast.import "PackageSystem"

module Y2Autoinstallation
  # Class responsible for finding packages for given sections. Uses yast2-schema.
  class PackagerSearcher
    include Yast::Logger

    # @param sections [Array<String>] section for which packages are required
    def initialize(sections)
      @sections = sections
    end

    # Process given list of sections
    # @return [Hash<String, Array<String>>] Required packages of a section. Return only
    #   packages that are not already installed.
    def evaluate
      package_names = {}
      log.info "Evaluating needed packages for handling AY-sections #{sections}"

      if !File.exist?(SCHEMA_PACKAGE_FILE)
        log.error "Cannot evaluate due to missing yast2-schema"
        return package_names
      end

      sections.each do |section|
        # Evaluate which *rng file belongs to the given section
        package_names[section] = []
        ret = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"),
          "/usr/bin/grep -l \"<define name=\\\"#{section}\\\">\" #{YAST_SCHEMA_DIR}")
        if ret["exit"] == 0
          ret["stdout"].split.uniq.each do |rng_file|
            # Evalute package name to which this rng file belongs to.
            package = package_name_of_schema(File.basename(rng_file, ".rng"))
            if package
              package_names[section] << package unless Yast::PackageSystem.Installed(package)
            else
              log.info("No package belongs to #{rng_file}.")
            end
          end
        else
          log.info("Cannot evaluate needed packages for AY section #{section}: #{ret.inspect}")
        end
      end

      package_names
    end

    YAST_SCHEMA_DIR = "/usr/share/YaST2/schema/autoyast/rng/*.rng".freeze
    private_constant :YAST_SCHEMA_DIR
    SCHEMA_PACKAGE_FILE = "/usr/share/YaST2/schema/autoyast/rnc/includes.rnc".freeze
    private_constant :SCHEMA_PACKAGE_FILE

  private

    attr_reader :sections

    # Returns package name of a given schema.
    # This information is stored in /usr/share/YaST2/schema/autoyast/rnc/includes.rnc
    # which will be provided by the yast2-schema package.
    #
    # @param schema <String> schema name like firewall, firstboot, ...
    # @return <String> package name or nil
    def package_name_of_schema(schema)
      if !@schema_package
        @schema_package = {}
        File.readlines(SCHEMA_PACKAGE_FILE).each do |line|
          line_split = line.split
          next if line.split.size < 4 # Old version of yast2-schema

          # example line
          #   include 'ntpclient.rnc' # yast2-ntp-client
          @schema_package[File.basename(line_split[1].delete("\'"), ".rnc")] = line.split.last
        end
      end
      @schema_package[schema]
    end
  end
end
