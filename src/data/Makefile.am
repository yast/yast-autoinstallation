#
# Makefile.am for y2c_autoinst/src
#
# $Id$
#

dtddir = /usr/share/autoinstall/dtd
xmldir = /usr/share/autoinstall/xslt
miscdir = /usr/share/autoinstall/

misc_DATA = \
	isolinux.cfg \
	EXTRA_PROV

ydata_DATA = \
	monitors.ycp

xml_DATA = \
    merge.xslt

dtd_DATA = $(wildcard *.dtd)

EXTRA_DIST = $(dtd_DATA) $(xml_DATA) $(ydata_DATA) $(misc_DATA)
