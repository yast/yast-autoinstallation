#
# Makefile.am for autoinstallation/src/data
#
# $Id$
#

SUBDIRS = dtd rng

xmldir = $(prefix)/share/autoinstall/xslt
miscdir = $(prefix)/share/autoinstall/

misc_DATA = \
	EXTRA_PROV


xml_DATA = \
    merge.xslt

fillupdir = /var/adm/fillup-templates/
fillup_DATA = sysconfig.autoinstall

EXTRA_DIST =  $(xml_DATA)  $(misc_DATA) $(fillup_DATA)  
