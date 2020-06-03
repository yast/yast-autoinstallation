# File:        clients/clone_system.ycp
# Package:     Auto-installation
# Author:      Uwe Gansert <ug@suse.de>
# Summary:     This client is clones some settings of the
#              system.

require "autoinstall/clients/clone_system"
Y2Autoinstallation::Clients::CloneSystem.new.main
