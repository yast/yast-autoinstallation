# Makefile.in generated automatically by automake 1.5 from Makefile.am.

# Copyright 1994, 1995, 1996, 1997, 1998, 1999, 2000, 2001
# Free Software Foundation, Inc.
# This Makefile.in is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY, to the extent permitted by law; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.



#
# Makefile.am for y2c_autoinst/src
#
# $Id$
#

SHELL = /bin/sh

srcdir = .
top_srcdir = ..

prefix = /usr
exec_prefix = ${prefix}

bindir = ${exec_prefix}/bin
sbindir = ${exec_prefix}/sbin
libexecdir = ${exec_prefix}/libexec
datadir = ${prefix}/share
sysconfdir = ${prefix}/etc
sharedstatedir = ${prefix}/com
localstatedir = ${prefix}/var
libdir = ${exec_prefix}/lib
infodir = ${prefix}/info
mandir = ${prefix}/man
includedir = ${prefix}/include/YaST2
oldincludedir = /usr/include
pkgdatadir = $(datadir)/yast2-config-autoinst
pkglibdir = $(libdir)/yast2-config-autoinst
pkgincludedir = $(includedir)/yast2-config-autoinst
top_builddir = ..

ACLOCAL = ${SHELL} /work/devel/autoyast/cvs/modules/y2c_autoinst/missing --run aclocal
AUTOCONF = ${SHELL} /work/devel/autoyast/cvs/modules/y2c_autoinst/missing --run autoconf
AUTOMAKE = ${SHELL} /work/devel/autoyast/cvs/modules/y2c_autoinst/missing --run automake
AUTOHEADER = ${SHELL} /work/devel/autoyast/cvs/modules/y2c_autoinst/missing --run autoheader

INSTALL = /usr/bin/install -c
INSTALL_PROGRAM = ${INSTALL}
INSTALL_DATA = ${INSTALL} -m 644
INSTALL_SCRIPT = ${INSTALL}
INSTALL_HEADER = $(INSTALL_DATA)
transform = s,x,x,
NORMAL_INSTALL = :
PRE_INSTALL = :
POST_INSTALL = :
NORMAL_UNINSTALL = :
PRE_UNINSTALL = :
POST_UNINSTALL = :
build_alias = i686-suse-linux
build_triplet = i686-suse-linux
host_alias = i686-suse-linux
host_triplet = i686-suse-linux
target_alias = i686-suse-linux
target_triplet = i686-suse-linux
AMTAR = ${SHELL} /work/devel/autoyast/cvs/modules/y2c_autoinst/missing --run tar
AWK = gawk
DEPDIR = .deps
DOCDIR = ${prefix}/share/doc/packages/yast2-config-autoinst
EXEEXT = 
INSTALL_STRIP_PROGRAM = ${SHELL} $(install_sh) -c -s
LN_S = ln -s
MAINTAINER = Anas Nashif <nashif@suse.de>
OBJEXT = o
PACKAGE = yast2-config-autoinst
RPMNAME = yast2-config-autoinst
VERSION = 2.6.4
YAST2DIR = /usr/lib/YaST2
YCPDOC = /usr/lib/YaST2/bin/ycpdoc
agentdir = ${prefix}/lib/YaST2/servers_non_y2
am__include = @am__include@
am__quote = @am__quote@
clientdir = ${prefix}/lib/YaST2/clients
configdir = ${prefix}/lib/YaST2/config
docdir = ${prefix}/share/doc/packages/yast2-config-autoinst
execcompdir = ${prefix}/lib/YaST2
imagedir = ${prefix}/lib/YaST2/images
install_sh = /work/devel/autoyast/cvs/modules/y2c_autoinst/install-sh
localedir = ${prefix}/lib/YaST2/locale
moduledir = ${prefix}/lib/YaST2/modules
plugindir = ${libdir}/YaST2/plugin
scrconfdir = ${prefix}/lib/YaST2/scrconf
yast2dir = ${prefix}/lib/YaST2
ybindir = ${prefix}/lib/YaST2/bin
ydatadir = ${prefix}/lib/YaST2/data
yncludedir = ${prefix}/lib/YaST2/include

SUBDIRS = include modules data

client_DATA = \
	autoyast.ycp \
	autoinst_tools.ycp \
	autoinst_bootloader.ycp \
	autoinst_general.ycp \
	autoinst_scripts.ycp \
	autoinst_storage.ycp \
	autoinst_software.ycp \
	autoinst_report.ycp


config_DATA = autoyast.y2cc autoinst_modules.conf

EXTRA_DIST = $(client_DATA)  $(config_DATA)
subdir = ./src
mkinstalldirs = $(SHELL) $(top_srcdir)/mkinstalldirs
CONFIG_CLEAN_FILES =
DIST_SOURCES =
DATA = $(client_DATA) $(config_DATA)


RECURSIVE_TARGETS = info-recursive dvi-recursive install-info-recursive \
	uninstall-info-recursive all-recursive install-data-recursive \
	install-exec-recursive installdirs-recursive install-recursive \
	uninstall-recursive check-recursive installcheck-recursive
DIST_COMMON = Makefile.am Makefile.in
DIST_SUBDIRS = $(SUBDIRS)
all: all-recursive

.SUFFIXES:
$(srcdir)/Makefile.in:  Makefile.am  $(top_srcdir)/configure.in $(ACLOCAL_M4)
	cd $(top_srcdir) && \
	  $(AUTOMAKE) --gnu  ./src/Makefile
Makefile:  $(srcdir)/Makefile.in  $(top_builddir)/config.status
	cd $(top_builddir) && \
	  CONFIG_HEADERS= CONFIG_LINKS= \
	  CONFIG_FILES=$(subdir)/$@ $(SHELL) ./config.status
uninstall-info-am:
install-clientDATA: $(client_DATA)
	@$(NORMAL_INSTALL)
	$(mkinstalldirs) $(DESTDIR)$(clientdir)
	@list='$(client_DATA)'; for p in $$list; do \
	  if test -f "$$p"; then d=; else d="$(srcdir)/"; fi; \
	  f="`echo $$p | sed -e 's|^.*/||'`"; \
	  echo " $(INSTALL_DATA) $$d$$p $(DESTDIR)$(clientdir)/$$f"; \
	  $(INSTALL_DATA) $$d$$p $(DESTDIR)$(clientdir)/$$f; \
	done

uninstall-clientDATA:
	@$(NORMAL_UNINSTALL)
	@list='$(client_DATA)'; for p in $$list; do \
	  f="`echo $$p | sed -e 's|^.*/||'`"; \
	  echo " rm -f $(DESTDIR)$(clientdir)/$$f"; \
	  rm -f $(DESTDIR)$(clientdir)/$$f; \
	done
install-configDATA: $(config_DATA)
	@$(NORMAL_INSTALL)
	$(mkinstalldirs) $(DESTDIR)$(configdir)
	@list='$(config_DATA)'; for p in $$list; do \
	  if test -f "$$p"; then d=; else d="$(srcdir)/"; fi; \
	  f="`echo $$p | sed -e 's|^.*/||'`"; \
	  echo " $(INSTALL_DATA) $$d$$p $(DESTDIR)$(configdir)/$$f"; \
	  $(INSTALL_DATA) $$d$$p $(DESTDIR)$(configdir)/$$f; \
	done

uninstall-configDATA:
	@$(NORMAL_UNINSTALL)
	@list='$(config_DATA)'; for p in $$list; do \
	  f="`echo $$p | sed -e 's|^.*/||'`"; \
	  echo " rm -f $(DESTDIR)$(configdir)/$$f"; \
	  rm -f $(DESTDIR)$(configdir)/$$f; \
	done

# This directory's subdirectories are mostly independent; you can cd
# into them and run `make' without going through this Makefile.
# To change the values of `make' variables: instead of editing Makefiles,
# (1) if the variable is set in `config.status', edit `config.status'
#     (which will cause the Makefiles to be regenerated when you run `make');
# (2) otherwise, pass the desired values on the `make' command line.
$(RECURSIVE_TARGETS):
	@set fnord $(MAKEFLAGS); amf=$$2; \
	dot_seen=no; \
	target=`echo $@ | sed s/-recursive//`; \
	list='$(SUBDIRS)'; for subdir in $$list; do \
	  echo "Making $$target in $$subdir"; \
	  if test "$$subdir" = "."; then \
	    dot_seen=yes; \
	    local_target="$$target-am"; \
	  else \
	    local_target="$$target"; \
	  fi; \
	  (cd $$subdir && $(MAKE) $(AM_MAKEFLAGS) $$local_target) \
	   || case "$$amf" in *=*) exit 1;; *k*) fail=yes;; *) exit 1;; esac; \
	done; \
	if test "$$dot_seen" = "no"; then \
	  $(MAKE) $(AM_MAKEFLAGS) "$$target-am" || exit 1; \
	fi; test -z "$$fail"

mostlyclean-recursive clean-recursive distclean-recursive \
maintainer-clean-recursive:
	@set fnord $(MAKEFLAGS); amf=$$2; \
	dot_seen=no; \
	case "$@" in \
	  distclean-* | maintainer-clean-*) list='$(DIST_SUBDIRS)' ;; \
	  *) list='$(SUBDIRS)' ;; \
	esac; \
	rev=''; for subdir in $$list; do \
	  if test "$$subdir" = "."; then :; else \
	    rev="$$subdir $$rev"; \
	  fi; \
	done; \
	rev="$$rev ."; \
	target=`echo $@ | sed s/-recursive//`; \
	for subdir in $$rev; do \
	  echo "Making $$target in $$subdir"; \
	  if test "$$subdir" = "."; then \
	    local_target="$$target-am"; \
	  else \
	    local_target="$$target"; \
	  fi; \
	  (cd $$subdir && $(MAKE) $(AM_MAKEFLAGS) $$local_target) \
	   || case "$$amf" in *=*) exit 1;; *k*) fail=yes;; *) exit 1;; esac; \
	done && test -z "$$fail"
tags-recursive:
	list='$(SUBDIRS)'; for subdir in $$list; do \
	  test "$$subdir" = . || (cd $$subdir && $(MAKE) $(AM_MAKEFLAGS) tags); \
	done

tags: TAGS

ID: $(HEADERS) $(SOURCES) $(LISP) $(TAGS_FILES)
	list='$(SOURCES) $(HEADERS) $(TAGS_FILES)'; \
	unique=`for i in $$list; do \
	    if test -f "$$i"; then echo $$i; else echo $(srcdir)/$$i; fi; \
	  done | \
	  $(AWK) '    { files[$$0] = 1; } \
	       END { for (i in files) print i; }'`; \
	mkid -fID $$unique $(LISP)

TAGS: tags-recursive $(HEADERS) $(SOURCES)  $(TAGS_DEPENDENCIES) \
		$(TAGS_FILES) $(LISP)
	tags=; \
	here=`pwd`; \
	list='$(SUBDIRS)'; for subdir in $$list; do \
	  if test "$$subdir" = .; then :; else \
	    test -f $$subdir/TAGS && tags="$$tags -i $$here/$$subdir/TAGS"; \
	  fi; \
	done; \
	list='$(SOURCES) $(HEADERS) $(TAGS_FILES)'; \
	unique=`for i in $$list; do \
	    if test -f "$$i"; then echo $$i; else echo $(srcdir)/$$i; fi; \
	  done | \
	  $(AWK) '    { files[$$0] = 1; } \
	       END { for (i in files) print i; }'`; \
	test -z "$(ETAGS_ARGS)$$unique$(LISP)$$tags" \
	  || etags $(ETAGS_ARGS) $$tags  $$unique $(LISP)

GTAGS:
	here=`CDPATH=: && cd $(top_builddir) && pwd` \
	  && cd $(top_srcdir) \
	  && gtags -i $(GTAGS_ARGS) $$here

distclean-tags:
	-rm -f TAGS ID GTAGS GRTAGS GSYMS GPATH

DISTFILES = $(DIST_COMMON) $(DIST_SOURCES) $(TEXINFOS) $(EXTRA_DIST)

top_distdir = ..
distdir = $(top_distdir)/$(PACKAGE)-$(VERSION)

distdir: $(DISTFILES)
	@for file in $(DISTFILES); do \
	  if test -f $$file; then d=.; else d=$(srcdir); fi; \
	  dir=`echo "$$file" | sed -e 's,/[^/]*$$,,'`; \
	  if test "$$dir" != "$$file" && test "$$dir" != "."; then \
	    $(mkinstalldirs) "$(distdir)/$$dir"; \
	  fi; \
	  if test -d $$d/$$file; then \
	    cp -pR $$d/$$file $(distdir) \
	    || exit 1; \
	  else \
	    test -f $(distdir)/$$file \
	    || cp -p $$d/$$file $(distdir)/$$file \
	    || exit 1; \
	  fi; \
	done
	for subdir in $(SUBDIRS); do \
	  if test "$$subdir" = .; then :; else \
	    test -d $(distdir)/$$subdir \
	    || mkdir $(distdir)/$$subdir \
	    || exit 1; \
	    (cd $$subdir && \
	      $(MAKE) $(AM_MAKEFLAGS) \
	        top_distdir="$(top_distdir)" \
	        distdir=../$(distdir)/$$subdir \
	        distdir) \
	      || exit 1; \
	  fi; \
	done
check-am: all-am
check: check-recursive
all-am: Makefile $(DATA)
installdirs: installdirs-recursive
installdirs-am:
	$(mkinstalldirs) $(DESTDIR)$(clientdir) $(DESTDIR)$(configdir)

install: install-recursive
install-exec: install-exec-recursive
install-data: install-data-recursive
uninstall: uninstall-recursive

install-am: all-am
	@$(MAKE) $(AM_MAKEFLAGS) install-exec-am install-data-am

installcheck: installcheck-recursive
install-strip:
	$(MAKE) $(AM_MAKEFLAGS) INSTALL_PROGRAM="$(INSTALL_STRIP_PROGRAM)" \
	  `test -z '$(STRIP)' || \
	    echo "INSTALL_PROGRAM_ENV=STRIPPROG='$(STRIP)'"` install
mostlyclean-generic:

clean-generic:

distclean-generic:
	-rm -f Makefile $(CONFIG_CLEAN_FILES) stamp-h stamp-h[0-9]*

maintainer-clean-generic:
	@echo "This command is intended for maintainers to use"
	@echo "it deletes files that may require special tools to rebuild."
clean: clean-recursive

clean-am: clean-generic mostlyclean-am

distclean: distclean-recursive

distclean-am: clean-am distclean-generic distclean-tags

dvi: dvi-recursive

dvi-am:

info: info-recursive

info-am:

install-data-am: install-clientDATA install-configDATA

install-exec-am:

install-info: install-info-recursive

install-man:

installcheck-am:

maintainer-clean: maintainer-clean-recursive

maintainer-clean-am: distclean-am maintainer-clean-generic

mostlyclean: mostlyclean-recursive

mostlyclean-am: mostlyclean-generic

uninstall-am: uninstall-clientDATA uninstall-configDATA \
	uninstall-info-am

uninstall-info: uninstall-info-recursive

.PHONY: $(RECURSIVE_TARGETS) GTAGS all all-am check check-am clean \
	clean-generic clean-recursive distclean distclean-generic \
	distclean-recursive distclean-tags distdir dvi dvi-am \
	dvi-recursive info info-am info-recursive install install-am \
	install-clientDATA install-configDATA install-data \
	install-data-am install-data-recursive install-exec \
	install-exec-am install-exec-recursive install-info \
	install-info-am install-info-recursive install-man \
	install-recursive install-strip installcheck installcheck-am \
	installdirs installdirs-am installdirs-recursive \
	maintainer-clean maintainer-clean-generic \
	maintainer-clean-recursive mostlyclean mostlyclean-generic \
	mostlyclean-recursive tags tags-recursive uninstall \
	uninstall-am uninstall-clientDATA uninstall-configDATA \
	uninstall-info-am uninstall-info-recursive uninstall-recursive

# Tell versions [3.59,3.63) of GNU make to not export all variables.
# Otherwise a system limit (for SysV at least) may be exceeded.
.NOEXPORT:
