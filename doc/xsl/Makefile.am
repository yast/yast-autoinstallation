XSLTPROC="/usr/bin/xsltproc"
STYLESHEETS=/usr/share/xml/docbook/stylesheet/nwalsh/current

CLEANFILES = mytitlepages.xsl

all: mytitlepages.xsl

mytitlepages.xsl: mytitlepage.templates.xml
	$(XSLTPROC) \
	--output $@ \ 
	$(STYLESHEETS)/template/titlepage.xsl $<


EXTRA_DIST = mytitlepage.templates.xml
