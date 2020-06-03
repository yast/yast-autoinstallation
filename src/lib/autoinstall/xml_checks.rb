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

require "autoinstall/xml_validator"
require "yast2/popup"

Yast.import "AutoinstConfig"

module Y2Autoinstallation
  class XmlChecks
    extend Yast::Logger
    extend Yast::I18n
    textdomain "autoinst"

    PROFILE_SCHEMA = "/usr/share/YaST2/schema/autoyast/rng/profile.rng".freeze
    RULES_SCHEMA = "/usr/share/YaST2/schema/autoyast/rng/rules.rng".freeze
    CLASSES_SCHEMA = "/usr/share/YaST2/schema/autoyast/rng/classes-use.rng".freeze

    def self.valid_profile?
      # TRANSLATORS: Error message
      msg = _("The AutoYaST profile is not a valid XML document.")
      check(Yast::AutoinstConfig.xml_tmpfile, PROFILE_SCHEMA, msg)
    end

    def self.valid_rules?
      # TRANSLATORS: Error message
      msg = _("The AutoYaST rules file is not a valid XML document.")
      check(Yast::AutoinstConfig.local_rules_file, RULES_SCHEMA, msg)
    end

    def self.valid_classes?(file)
      # TRANSLATORS: Error message
      msg = _("The AutoYaST class file is not a valid XML document.")
      check(file, RULES_SCHEMA, msg)
    end

    def self.check(file, schema, msg)
      validator = XmlValidator.new(file, schema)
      return true if validator.valid?

      Yast2::Popup.show(error_message(msg, file, schema),
        headline: :error, details: validator.errors.join("\n"),
        buttons: { abort: Yast::Label.AbortButton })
      false
    end

    private_class_method :check

    def self.error_message(msg, file, schema)
      xml_file = File.basename(file)
      jing_command = "jing #{schema} #{xml_file}"
      xmllint_command = "xmllint --noout --relaxng #{schema} #{xml_file}"

      # TRANSLATORS: A hints how to check a XML file, displayed as a part of the
      # validation error message, %{jing} and %{xmllint} are replaced by shell commands
      msg += "\n\n" + _("You can check the file with these commands:\n\n" \
        "  %{jing}\n" \
        "  %{xmllint}"
      ) % {jing: jing_command, xmllint: xmllint_command}
    end

    private_class_method :error_message
  end
end