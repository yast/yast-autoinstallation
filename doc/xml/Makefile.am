#
# Makefile.am for y2c_autoinst/doc
#
# $Id: Makefile.am 63765 2011-04-11 15:40:31Z ug $
#

SUBDIRS = images entities
htmldir = $(docdir)/html

xml_file = autoyast.xml
xml_files = $(wildcard *.xml)
ent_files = $(wildcard *.ent)

EXTRA_DIST = $(xml_files) $(ent_files) $(wildcard *.xsl) \
  web/default.css bin entities examples

CLEANFILES = .html.sum  profile.dtd.xml elements \
  elements.xml elements.ent profile.dtd.xml examples.ent\
  components.ent .ps.sum  autoyast.out autoyast.pdf autoyast.fo \
  images.ent \
  ay_bigfile_docbook.xml ay_bigfile_novdoc.xml ay_bigfile.xml

STYLESHEET_CSS = default.css

#html_DATA = html
#doc_DATA = pdf


DAPS_BASE := $(shell readlink -f ..)

#html_DATA = $(wildcard html/*.html) \
#	    html/index.html \
#	    html/yast2docs.css \
#		html/default.css

#doc_DATA = autoyast.pdf

#.PHONY: pdf html pkgsrc html-debug entities
.PHONY: html pkgsrc html-debug entities

html: $(xml_files) autoyast.xml prep-daps-images entities ay_bigfile.xml
html: RESULTDIR="..//build/autoyast/html/autoyast"
#html: RESULTDIR := $(shell daps -e ENV-autoyast --basedir=$(DAPS_BASE) html-dir-name 2>/dev/null)
html:
	daps -e ENV-autoyast --basedir=$(DAPS_BASE) html --static
	rm -rf html && mkdir -p html
	cp -a $(RESULTDIR)/* html

#pdf: $(xml_files) autoyast.xml prep-daps-images entities ay_bigfile.xml
#pdf: PDF_FILE="..//build/autoyast/autoyast_en.pdf"
#pdf: PDF_FILE := $(shell daps -e ENV-autoyast --basedir=$(DAPS_BASE) color-pdf-name 2>/dev/null)
#pdf:
#	daps -e ENV-autoyast --basedir=$(DAPS_BASE) pdf-color
#	mkdir -p pdf
#	echo "$(PDF_FILE) xxx"
#	cp -a $(PDF_FILE) pdf

pkgsrc: $(xml_files) autoyast.xml prep-daps-images entities ay_bigfile.xml
	daps -e ENV-autoyast --basedir=$(DAPS_BASE) package-src

html-debug: $(xml_files) autoyast.xml prep-daps-images entities ay_bigfile.xml
	daps --debug -e ENV-autoyast --basedir=$(DAPS_BASE) html

#bigfile:
#	cd xml; make ay_bigfile.xml




entities: components.ent examples.ent images.ent

components.ent:
	bin/components.sh noref > components.ent

examples.ent:
	bin/examples.sh > examples.ent

images.ent:
	@make -r -C images/WEB -f makefile.ent ima

# was: images/PNG/*.png 
prep-daps-images:
	mkdir -p ../images/src/png

ay_bigfile_docbook.xml: autoyast.xml $(xml_files) prep-daps-images entities
# Remove internal entity statements
	{ head -n 3 $< ; \
	XML_CATALOG_FILES=@XML_CATALOG@ \
	xmllint --xinclude --noent --nocdata -o - $< \
	  | awk 'BEGIN{b=0}; /^]>/ && b == 0 {b=1}; b == 1 {print}' \
	  | sed -e 's|fileref=\"img/|fileref=\"|' \
	        -e 's|<acronym>|<phrase role=\"acronym\">|g' \
	        -e 's|</acronym>|</phrase>|g' \
	        -e 's|<caution>|<!-- role=\"caution\" --><note>|g' \
	        -e 's|</caution>|</note>|g' \
	        -e 's|<literallayout|<!-- role=\"literallayout\" --><screen|g' \
	        -e 's|</literallayout>|</screen>|g' \
	        -e 's|<orderedlist numeration=\"arabic\">|<!-- numeration=\"arabic\" --><orderedlist>|g' \
		-e 's|title id=[^>]*|title|' \
		-e 's|endterm=[^/]*||' \
		-e 's|frame=\"top\"||g' \
		-e "s|frame='top'||g" \
		-e 's|revision=\"1\"||g' \
		-e 's|align=\"center\"||' ; } > $@

ay_bigfile.xml: ay_bigfile_docbook.xml
	xsltproc --output $@ \
	  /usr/share/daps/xslt/misc/db2novdoc.xsl $<

#install-data-local: html pdf
install-data-local: html
#install-data-local: PDF_FILE="..//build/autoyast/autoyast_en.pdf"
#install-data-local: PDF_FILE := $(shell daps -e ENV-autoyast --basedir=$(DAPS_BASE) color-pdf-name 2>/dev/null)
install-data-local:
	install -d -m 755 $(DESTDIR)$(htmldir)
	cp -a $(srcdir)/html/* $(DESTDIR)$(htmldir)
#	cp -a $(srcdir)/$(shell basename $(PDF_FILE)) $(docdir)
#	cp -a $(srcdir)/html/images $(DESTDIR)$(htmldir)
#	cp -a $(srcdir)/html/img $(DESTDIR)$(htmldir)
#	cp -a $(srcdir)/html/devel $(DESTDIR)$(htmldir)

clean-local:
	rm -rf html



#html/index.html: autoyast.xml
#	XML_CATALOG_FILES=@XML_CATALOG@ \
#	time -p  @XSLTPROC@ --xinclude \
#	-stringparam chunk.fast '1' \
#	--stringparam html.stylesheet $(STYLESHEET_CSS) \
#	@STYLESHEET_HTML@ autoyast.xml
#	XML_CATALOG_FILES=@XML_CATALOG@ \
#	time -p  @XSLTPROC@ --xinclude \
#	-stringparam base.dir 'html/devel/' \
#	-stringparam chunk.fast '1' \
#	--stringparam show.comments '0' \
#	--stringparam html.stylesheet $(STYLESHEET_CSS) \
#	@STYLESHEET_HTML@ creating_autoyast2_modules.xml
#	cd html/devel; \
#	ln -s ../default.css ./default.css; \
#	cd ../..

#html/index.html: autoyast.xml 
#	XML_CATALOG_FILES=@XML_CATALOG@ \
#	@XSLTPROC@ --xinclude \
#	--stringparam show.comments '0' \
#	@STYLESHEET_HTML@ \
#	$<


# Not in use; use ay_bigfile.xml
#ay_bigfile_novdoc.xml: prep-daps-images
#ay_bigfile_novdoc.xml: autoyast.xml
#	{ echo '<?xml version="1.0" encoding="UTF-8"?>'; \
#	  echo '<!DOCTYPE book PUBLIC "-//Novell//DTD NovDoc XML V1.0//EN" "novdocx.dtd"'; \
#	  echo '['; \
#	  echo '<!ENTITY % NOVDOC.DEACTIVATE.IDREF "INCLUDE">'; \
#	XML_CATALOG_FILES=@XML_CATALOG@ \
#	xmllint --xinclude --noent --nocdata -o - $< \
#	  | awk 'BEGIN{b=0}; /^]>/ && b == 0 {b=1}; b == 1 {print}' \
#	  | sed 's|fileref=\"img/|fileref=\"|' ; } > $@

#autoyast.fo: autoyast.xml
#	XML_CATALOG_FILES=@XML_CATALOG@ \
#	@XSLTPROC@ @XSLTPROC_FLAGS@ --xinclude \
#	-o $@ @STYLESHEET_PDF@  $<

#autoyast.fo: autoyast.xml
#	saxon -o autoyast.fo autoyast.xml @STYLESHEET_PDF@

#autoyast.pdf: autoyast.fo
#	fop -q $< $@

#autoyast.xml: images.ent examples components

#html/yast2docs.css: html/index.html
#	cp @STYLESHEET_CSS@ html
#	cp -a $(ydatadir)/docbook/images html

#html/default.css: html/index.html webimages
#	cp web/default.css html

#: images.ent chunks webimages


#webimages:
#	mkdir -p html/img
#	cp -a images/WEB/*png html/img


#.PHONY: images examples.ent components.ent

#images: images/EPS/* images/PNG/* 
#	@if ! [ -e "img" ]; then \
#		mkdir -p img; \
#	fi
#	@if ! [ -e "img/Makefile" ]; then \
#		ln -s ../images/makefile.images img/Makefile; \
#	fi

#	@echo "generating PNG files for all outputs...";
#	@if [ "$(IMAGES)" = "all" ]; then \
#		rm -f img/*.{png,pdf}; \
#	fi;

#	@for j in `bin/findImages.sh` ; do \
#		if [ -e "images/EPS/$$j" ]; then \
#			source="images/EPS/$$j"; eps="1";\
#		elif [ -e "images/PNG/$$j" ]; then \
#			source="images/PNG/$$j"; eps="0"; \
#		fi; \
#		dest=`echo "img/$$j" | sed -e "s|_|-|g;s|.eps||g;s|.png||g;"`; \
#		if [ -e "$$source" ]; then \
#			if [ ! -f $$dest".png" ] || [ $$dest".png" -ot $$source ]; then \
#				if  [ $$eps == "1" ]; then \
#					echo "	converting $$source -> $$dest'.pdf'"; \
#					bin/epstopdf12 -o=$$dest".pdf" $$source; \
#					echo "	converting $$source -> $$dest'.png'"; \
#					convert $$source $$dest".png"; \
#				else \
#					echo "	linking $$source -> $$dest'.png'"; \
#					convert -depth 8 $$source $$dest".png"; \
#				fi; \
#			fi; \
#		fi; \
#	done
#	@make -r -C img  ima


