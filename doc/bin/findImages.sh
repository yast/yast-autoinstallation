#!/bin/sh

# litte shell script to search for all images to be converted ...

LANG=$1;

cd "images";
find *.eps PNG/*.png 2>/dev/null \
	| sed -e "s#EPS/##; s#PNG/##" \
	| sort -u; 
