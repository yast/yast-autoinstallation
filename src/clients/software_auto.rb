# File:  clients/autoinst_software.ycp
# Package:  Autoinstallation Configuration System
# Authors:  Anas Nashif (nashif@suse.de)
# Summary:  Handle Package selections and packages

require "autoinstall/clients/software_auto"
Y2Autoinstallation::Clients::SoftwareAuto.new.main
