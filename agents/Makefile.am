#
# Makefile.am for y2c_autoinst/agents
#
# $Id$
#

agentsdir = $(YAST2DIR)/servers_non_y2

agents_SCRIPTS = ag_yast1sel
scrconf_DATA = $(wildcard *.scr)

fillupdir = /var/adm/fillup-templates/
fillup_DATA = sysconfig.autoinstall

EXTRA_DIST = $(scrconf_DATA) $(fillup_DATA) $(agents_SCRIPTS)
