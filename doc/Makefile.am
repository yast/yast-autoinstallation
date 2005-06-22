#
# Makefile.am for y2c_autoinst/doc
#
# $Id$
#

SUBDIRS = autodocs images entities bin components examples xsl
htmldir = $(docdir)/html

xml_file = autoyast.xml
xml_files =  $(wildcard *.xml) 


EXTRA_DIST = $(xml_files) $(wildcard *.xsl) 

CLEANFILES = .html.sum  profile.dtd.xml elements \
  elements.xml elements.ent profile.dtd.xml examples.ent\
  components.ent .ps.sum  autoyast.out autoyast.pdf \
  images.ent 

STYLESHEET_CSS = default.css

html_DATA = $(wildcard html/*.html) \
	    html/index.html \
	    html/yast2docs.css 

components: components.ent
	bin/components.sh noref > components.ent

examples: examples.ent
	bin/examples.sh > examples.ent

html/index.html: autoyast.xml
	XML_CATALOG_FILES=@XML_CATALOG@ \
	time -p  @XSLTPROC@ --xinclude \
	-stringparam chunk.fast '1' \
	--stringparam html.stylesheet $(STYLESHEET_CSS) \
	@STYLESHEET_HTML@ autoyast.xml
					

#html/index.html: autoyast.xml 
#	XML_CATALOG_FILES=@XML_CATALOG@\
#	@XSLTPROC@ --xinclude  @STYLESHEET_HTML@ \
#	$<

autoyast.fo: autoyast.xml
	XML_CATALOG_FILES=@XML_CATALOG@ \
	@XSLTPROC@ @XSLTPROC_FLAGS@ --xinclude \
	-o $@ @STYLESHEET_PDF@  $<

autoyast.pdf: autoyast.fo
	fop -q $< $@

autoyast.xml: images.ent examples components

html/yast2docs.css: html/index.html
	cp @STYLESHEET_CSS@ html
	cp web/default.css html
	cp -a $(ydatadir)/docbook/images html



images.ent:
	@make -r -C images/WEB -f makefile.ent ima

: images.ent chunks webimages


webimages:
	mkdir -p html/img
	cp -a images/WEB/*png html/img


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
	@make -r -C img  ima


install-data-local:
	install -d -m 755 $(DESTDIR)$(htmldir)
	cp -a $(srcdir)/html/images $(DESTDIR)$(htmldir)
	cp -a $(srcdir)/html/images $(DESTDIR)$(htmldir)


clean-local:
	rm -rf html

