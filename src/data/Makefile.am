#
# Makefile.am for y2c_autoinst/src
#
# $Id$
#

SUBDIRS = dtd rng

xmldir = /usr/share/autoinstall/xslt
miscdir = /usr/share/autoinstall/

misc_DATA = \
	EXTRA_PROV

#ydata_DATA = \
#	monitors.ycp

xml_DATA = \
    merge.xslt

fillupdir = /var/adm/fillup-templates/
fillup_DATA = sysconfig.autoinstall

EXTRA_DIST =  $(xml_DATA)  $(misc_DATA) $(fillup_DATA) #  $(ydata_DATA)
