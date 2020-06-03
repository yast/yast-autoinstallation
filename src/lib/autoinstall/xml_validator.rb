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

Yast.import "XML"

module Y2Autoinstallation
  class XmlValidator
    include Yast::Logger

    attr_reader :xml, :schema

    def initialize(xml, schema)
      @xml = xml
      @schema = schema
      @errors = nil
    end

    def errors
      return @errors if @errors
      validate
      @errors
    end

    def valid?
      return @errors.empty? if @errors
      validate
      @errors.empty?
    end

    private

    def validate
      if ENV["YAST_SKIP_XML_VALIDATION"] == "1"
        log.info "Skipping XML validation on user request"
        @errors = []
        return
      end

      log.info "Validating #{xml} against #{schema}..."
      @errors = Yast::XML.validate(xml, schema)

      if errors.empty?
        log.info "The XML is valid"
      else
        log.error "XML validation errors: #{errors.inspect}"
      end
    rescue Yast::XMLDeserializationError => e
      log.error "Cannot parse XML: #{e.message}"
      @errors = [ e.message ]
    end
  end
end
