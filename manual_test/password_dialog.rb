$LOAD_PATH << File.expand_path("../src/lib", __dir__)

require "yast"
require "yast2/popup"
require "autoinstall/password_dialog"

res = Y2Autoinstallation::PasswordDialog.new("Test").run
Yast2::Popup.show("Dialog returns #{res.inspect}")
