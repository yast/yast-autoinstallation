#
# Makefile.am for y2c_autoinst/doc
#
# $Id$
#

SUBDIRS = autodocs images entities bin components examples

htmldir = @docdir@
xml_file = autoyast2.xml
style_file = autoyast2.dsl
xml_files =  $(wildcard *.xml) 

EXTRA_DIST = 

CLEANFILES = *.dvi *.aux *.tex *.log *.bak *.out\
  .html.sum; rm -rf autoyast2 autoyast2.junk profile.dtd.xml elements \
  elements.xml elements.ent db2html.* profile autoyast2.ps*		\
  profile.dtd.xml examples.ent components.ent .ps.sum  autoyast2.out autoyast2.pdf \
  images.ent img



components: components.ent
	bin/components.sh noref > components.ent
examples: examples.ent
	bin/examples.sh > examples.ent

date:
	date > systemdate

pdf: $(xml_files) examples components images
		if test -e .ps.sum; then \
			oldsum="`cat .ps.sum`"; \
		fi;\
		sum ./$(xml_file) > .ps.sum; \
		newsum="`cat .pdf.sum`"; \
		if ! test "$$oldsum" = "$$newsum" || ! test -f autoyast2.pdf; then \
			db2pdf  $(xml_file); \
		fi;

html:  $(xml_files) examples components images
		rm -rf autoyast2; \
		db2html  $(xml_file); \
		mkdir -p autoyast2/img; \
		cp  img/*.png autoyast2/img; 


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
