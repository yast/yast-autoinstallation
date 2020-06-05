# File:  clients/autoyast.ycp
# Summary:  Main file for client call
# Authors:  Anas Nashif <nashif@suse.de>

require "autoinstall/clients/autoyast"
Y2Autoinstallation::Clients::Autoyast.new.main
