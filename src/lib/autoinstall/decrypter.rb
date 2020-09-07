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
require "shellwords"

Yast.import "UI"
Yast.import "Label"

module Y2Autoinstallation
  # Responsible for decrypting content e.g. profile.
  #
  class Decrypter
    extend Yast::I18n
    extend Yast::UIShortcuts
    # @param file [String] file that is encrypted.
    # @param label [String] localized title when asking user for password
    #   like "Encrypted AutoYast profile."
    # @return [String] decrypted content. If content is not encrypted, it is returned.
    def self.decrypt(file, label)
      content = ::File.read(file)
      return content unless encrypted?(content)

      textdomain "autoinst"

      Yast::UI.OpenDialog(
        VBox(
          Label(
            label + " " + _("Please provide a password.")
          ),
          Password(Id(:password), ""),
          PushButton(Id(:ok), Yast::Label.OKButton)
        )
      )

      output = nil
      loop do
        res = Yast::UI.UserInput
        next if res != :ok

        password = Yast::UI.QueryWidget(:password, :Value)

        # use SCR instead of cheetah due to logging
        output = Yast::SCR.Execute(
          Yast::Path.new(".target.bash_output"),
          "/usr/bin/gpg2 --decrypt --batch --passphrase #{password.shellescape} #{file.shellescape}"
        )

        if output["exit"] != 0
          Yast::Popup.Error(_("Failed to decrypt file. Error:\n") + output["stderr"])
        else
          break
        end
      end

      Yast::UI.CloseDialog

      output["stdout"]
    end

    # @return [Boolean] if content is gpg encrypted
    def self.encrypted?(content)
      content.lines.first&.strip == "-----BEGIN PGP MESSAGE-----"
    end
  end
end
