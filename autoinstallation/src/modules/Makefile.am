#
# Makefile.am for y2m_autoinst/src/module
#

YCPCFLAGS = -I ./dialogs -I ./include

module_DATA = $(wildcard *.ycp)

EXTRA_DIST =                    \
	$(module_DATA)

dialogs:
	mkdir dialogs && ln -sf ../../dialogs dialogs/autoinstall

include:
	mkdir include && ln -sf ../../include include/autoinstall


#	test -L autoinstall || ln -sf ../include autoinstall

ycpchook = dialogs include

include $(top_srcdir)/Makefile.am.common


