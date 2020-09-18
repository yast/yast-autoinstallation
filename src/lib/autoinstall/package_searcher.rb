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
require "y2packager/resolvable"

Yast.import "PackageSystem"

module Y2Autoinstallation
  # Class responsible for finding packages for given sections. Uses yast2-schema.
  class PackagerSearcher
    include Yast::Logger

    # @param sections [Array<String>] sections for which packages are required
    def initialize(sections)
      @sections = sections
    end

    # Gets packages that needs to be installed via RPM supplements.
    # @return [Hash<String, Array<String>>] Required packages of a section.
    def evaluate_via_rpm
      package_names = {}
      log.info "Evaluating needed packages for handling AY-sections via RPM Supplements"
      log.info "Sections: #{sections}"
      packages = Y2Packager::Resolvable.find(
        kind:               :package,
        # this is a POSIX extended regexp, not a Ruby regexp!
        supplements_regexp: "^autoyast\\(.*\\)"
      )

      sections.each do |section|
        # Evaluting which package has the supplement autoyast(<section>)
        package_names[section] = []
        packages.each do |p|
          p.deps.each do |dep|
            next if !dep["supplements"] ||
              !dep["supplements"].match(/^autoyast\((.*)\)/)

            suppl_sections = Regexp.last_match(1).split(":")
            suppl_sections.each do |sup_section|
              next unless sup_section == section

              log.info("Package #{p.name} supports section #{section}" \
                       " via supplement.")
              package_names[section] << p.name
            end
          end
        end
      end

      package_names
    end

  private
    attr_reader :sections

  end
end
