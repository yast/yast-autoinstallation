#
# Makefile.am for y2c_autoinst/doc
#
# $Id$
#

SUBDIRS = autodocs images entities bin components examples xsl

xml_file = autoyast.xml
xml_files =  $(wildcard *.xml) 

CATALOG="./catalog.xml"
XSLTPROC="/usr/bin/xsltproc"
IMAGES=/usr/share/xml/docbook/stylesheet/nwalsh/current/images
STYLESHEETS=/usr/share/xml/docbook/stylesheet/nwalsh/current
BUILD=build


EXTRA_DIST = $(xml_files) $(wildcard *.xsl) $(wildcard *.css)

CLEANFILES = *.dvi *.aux *.tex *.log *.bak *.out\
  .html.sum autoyast.junk profile.dtd.xml elements \
  elements.xml elements.ent db2html.* profile autoyast.ps*		\
  profile.dtd.xml examples.ent components.ent .ps.sum  autoyast.out autoyast.pdf \
  images.ent 


all: html

components: components.ent
	bin/components.sh noref > components.ent
examples: examples.ent
	bin/examples.sh > examples.ent

chunks: $(xml_files) examples components 
	XML_CATALOG_FILES=$(CATALOG) \
	xsltproc \
	-stringparam base.dir "$(BUILD)/" \
	--xinclude \
	chunks.xsl \
	autoyast.xml

html: builddir chunks style stylesheet-images webimages

builddir: 
	mkdir -p $(BUILD)
	@make -r -C images/WEB -f makefile.ent ima

style:
	cp style.css $(BUILD)

webimages:
	mkdir -p build/img
	cp -a images/WEB/*png build/img

stylesheet-images:
	cp -a $(IMAGES) $(BUILD)

autoyast.fo: print.xsl $(xml_files) examples components images
	XML_CATALOG_FILES=$(CATALOG) \
	$(XSLTPROC) --output autoyast.fo --xinclude  print.xsl  autoyast.xml


pdf: autoyast.fo
	fop autoyast.fo autoyast.pdf


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
	install -d -m 755 $(DESTDIR)/@docdir@/html
	cp -a build/* $(DESTDIR)/@docdir@/html

