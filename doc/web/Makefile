PROC=xsltproc
STYLEDIR=./xsl
TABSTYLE=./xsl/mine.xsl
STYLESHEET=$(TABSTYLE)
# Change the path in output-root to put your HTML output elsewhere
DESTDIR=html
STYLEOPT= --stringparam output-root $(DESTDIR)  --xinclude -stringparam admon.graphics 1

.PHONY : clean 

all: style images
	make website

include depends.tabular

autolayout.xml: layout.xml
	$(PROC) --output $@ $(STYLEDIR)/autolayout.xsl $<
	make depends

%.html: autolayout.xml 
	$(PROC) --output $@  $(STYLEOPT)  $(STYLESHEET)  $(filter-out autolayout.xml,$^) 

depends: autolayout.xml
	$(PROC) --output depends.tabular $(STYLEOPT) $(STYLEDIR)/makefile-dep.xsl $<

sync:
	rsync -avz -e ssh  $(DESTDIR)/* minkowski:~/public_html/autoinstall/

sync-intern:
	rsync -avz -e ssh  $(DESTDIR)/* minkowski:~/Export/autoinstall/

style: $(DESTDIR)/style/default.css

$(DESTDIR)/style/default.css:
	mkdir -p $(DESTDIR)/style
	cp default.css $(DESTDIR)/style

$(DESTDIR)/images:
	mkdir -p $(DESTDIR)/images

$(DESTDIR)/graphics:
	mkdir -p $(DESTDIR)/graphics
	
images: $(DESTDIR)/images $(DESTDIR)/graphics
	cp -a images $(DESTDIR)/
	cp -a graphics $(DESTDIR)/
	
