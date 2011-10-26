#
# Makefile.am for y2c_autoinst/doc
#
# $Id$
#

SUBDIRS = xml autodocs entities bin components examples xsl
htmldir = $(docdir)/html


pdf: xml/ay_bigfile.xml
	daps -e ENV-autoyast pdf-color

html: xml/ay_bigfile.xml
	daps -e ENV-autoyast html

html-debug: xml/ay_bigfile.xml
	daps --debug -e ENV-autoyast html

xml/ay_bigfile.xml:
	cd xml; make ay_bigfile.xml
