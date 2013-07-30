#
# Makefile.am for y2c_autoinst/src
#
# $Id$
#
controldir = $(yast2dir)/control

control_DATA = \
    control_continue_autoyast.xml

EXTRA_DIST =                    \
	$(control_DATA)

check-local:
	xmllint --relaxng $(controldir)/control.rng --noout $(control_DATA)

include $(top_srcdir)/Makefile.am.common
