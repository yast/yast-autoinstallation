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
BUILD=html
STYLESHEET_FO=$(ydatadir)/docbook/stylesheets/customize-fo.xsl
STYLESHEET_HTML=$(ydatadir)/docbook/stylesheets/customize-html.xsl



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
	xsltproc \
	-stringparam base.dir "$(BUILD)/" \
	--xinclude \
	$(STYLESHEET_HTML) \
	autoyast.xml
$(BUILD)/susebooks.css:
	cp $(ydatadir)/docbook/css/susebooks.css $(BUILD)
	cp -a $(ydatadir)/docbook/images $(BUILD)


images.ent:
	@make -r -C images/WEB -f makefile.ent ima

html: images.ent chunks webimages $(BUILD)/susebooks.css


webimages:
	mkdir -p $(BUILD)/img
	cp -a images/WEB/*png $(BUILD)/img

autoyast.fo: print.xsl $(xml_files) examples components images
	$(XSLTPROC) --output autoyast.fo --xinclude  $(STYLESHEET_FO)  autoyast.xml


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
	cp -a $(BUILD)/* $(DESTDIR)/@docdir@/html

