#
# Makefile.am for y2c_autoinst/doc
#
# $Id$
#

SUBDIRS = autodocs images entities bin components examples

htmldir = @docdir@
xml_file = autoyast2.xml
style_file = autoyast2.dsl
xml_files =  	$(wildcard *.xml) \
		purpose.xml

EXTRA_DIST = $(xml_files) $(style_file) dtdparse.tgz profile.dtd

CLEANFILES = autoyast2.dvi autoyast2.aux autoyast2.tex autoyast2.log \
  .html.sum; rm -rf autoyast2 autoyast2.junk profile.dtd.xml elements \
  elements.xml elements.ent db2html.* profile autoyast2.ps*		\
  profile.dtd.xml examples.ent components.ent .ps.sum  autoyast2.out autoyast2.pdf \
  images.ent img

elements = elements.xml elements.ent


minimal: date minimal-examples.ent minimal-compoenents html pdf

minimal-examples.ent:
	bin/examples.sh min > examples.ent
	

minimal-compoenents:
	bin/components.sh min > components.ent



full: full-examples.ent full-components dtdparse/dtdparse profile/elements.ent html

full-components:
	bin/components.sh > components.ent
full-examples.ent:
	bin/examples.sh > examples.ent

date:
	date > systemdate
all: date full

install-data-am: $(xml_file)  
	mkdir -p $(DESTDIR)$(docdir)/xml/images; \
	mkdir -p $(DESTDIR)$(docdir)/html; \
	$(INSTALL_DATA) $(srcdir)/$(xml_files) $(DESTDIR)$(docdir)/xml/; \
	for img in $(srcdir)/images/*.eps; do \
		$(INSTALL_DATA) $$img $(DESTDIR)$(docdir)/xml/images;\
	done ;\
	if test -d autoyast2; then \
		cp -axp autoyast2/* $(DESTDIR)$(docdir)/html/; \
	fi

pdf: components.ent examples.ent
		if test -e .ps.sum; then \
			oldsum="`cat .ps.sum`"; \
		fi;\
		sum ./$(xml_file) > .ps.sum; \
		newsum="`cat .pdf.sum`"; \
		if ! test "$$oldsum" = "$$newsum" || ! test -f autoyast2.pdf; then \
			db2pdf  $(xml_file); \
		fi;

dtdparse/dtdparse: 
		tar zxvf dtdparse.tgz;

profile/elements.ent: purpose.xml profile.dtd
		./dtdparse/dtdparse profile.dtd; \
		./dtdparse/dtdformat --refentry --purpose profile.dtd.xml; \
		if test -e "profile/elements.ent"; then \
			cp -a profile/elements* .; \
		fi; 

html: images $(xml_files) 
		if ! test -e ./$(xml_file); then \
			cp $(srcdir)/$(xml_file) . ; \
			cp -ax $(srcdir)/images . ; \
		fi; \
		if test -e .html.sum; then \
			oldsum="`cat .html.sum`"; \
		fi;\
		sum ./$(xml_file) > .html.sum; \
		newsum="`cat .html.sum`"; \
		if ! test "$$oldsum" = "$$newsum" || ! test -d autoyast2; then \
			rm -rf autoyast2; \
			db2html  $(xml_file); \
			mkdir -p autoyast2/img; \
			cp  img/*.png autoyast2/img; \
		fi; 

publish: html
		rm -rf $(HOME)/public_html/autoyast2;\
		rm -rf $(HOME)/Export/autoinstall/autoyast2;\
		cp -a autoyast2 $(HOME)/public_html/autoyast2; \
		cp -a autoyast2 $(HOME)/Export/autoinstall/autoyast2; \
		chmod -R a+r $(HOME)/public_html/autoyast2; \
		chmod a+x `find $(HOME)/public_html/autoyast2 -type d`;\
		chmod -R a+r $(HOME)/Export/autoinstall/autoyast2; \
		chmod a+x `find $(HOME)/Export/autoinstall/autoyast2 -type d`;

.PHONY: images examples.ent components.ent

images: images/EPS/* images/PNG/* 
	@if ! [ -e "img" ]; then \
		mkdir -p img; \
	fi
	@if ! [ -e "img/Makefile" ]; then \
		ln -s ../images/makefile.images img/Makefile; \
	fi


	@echo "generating PNG files for all outputs...";
	@if [ "$(IMAGES)" = "all" ]; then \
		rm -f img/*.{png,pdf}; \
	fi;

	@for j in `bin/findImages.sh` ; do \
		if [ -e "images/EPS/$$j" ]; then \
			source="images/EPS/$$j"; eps="1";\
		elif [ -e "images/PNG/$$j" ]; then \
			source="images/PNG/$$j"; eps="0"; \
		fi; \
		dest=`echo "img/$$j" | sed -e "s|_|-|g;s|.eps||g;s|.png||g;"`; \
		if [ -e "$$source" ]; then \
			if [ ! -f $$dest".png" ] || [ $$dest".png" -ot $$source ]; then \
				if  [ $$eps == "1" ]; then \
					echo "	converting $$source -> $$dest'.pdf'"; \
					bin/epstopdf12 -o=$$dest".pdf" $$source; \
					echo "	converting $$source -> $$dest'.png'"; \
					convert $$source $$dest".png"; \
				else \
					echo "	linking $$source -> $$dest'.png'"; \
					convert -depth 8 $$source $$dest".png"; \
				fi; \
			fi; \
		fi; \
	done
# copy admonition images
#@cp -u images/{tip,note,warning}.png img/;
	@make -r -C img  ima
