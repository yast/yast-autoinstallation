#
# Makefile.am for y2m_autoinst/src/module
#

YCPCFLAGS = -I ./dialogs -I ./include

module_DATA = $(wildcard *.ycp)

EXTRA_DIST =                    \
	$(module_DATA)

symlinks:
	test -d dialogs || mkdir dialogs && ln -sf ../../dialogs dialogs/autoinstall
	test -d include || mkdir include && ln -sf ../../include include/autoinstall


#	test -L autoinstall || ln -sf ../include autoinstall

ycpchook = symlinks

include $(top_srcdir)/Makefile.am.common


