#!/bin/bash

_exit_on_error () {
    echo "Error: $1" >&2
    exit 1
}

ENVFILE="ENV-autoyast"

CHECKOUT_DIR=$(readlink -m $(dirname $0))
CHECKOUT_DIR=$(dirname $CHECKOUT_DIR)

echo "Running make"

cd $CHECKOUT_DIR
make -f Makefile.cvs > /dev/null || _exit_on_error "Autogenerating Makefiles failed"

cd ${CHECKOUT_DIR}/doc/xml
make > /dev/null || _exit_on_error "Autogenerating docs failed" 

echo "Linking Images"
mkdir -p ${CHECKOUT_DIR}/doc/images/src/png
cd ${CHECKOUT_DIR}/doc/images/src/png
for IMG in ../../../autoyast2/img/*.png; do
    ln -sf "$IMG" || "Warning: could not link $IMG" 
done

cd ${CHECKOUT_DIR}/doc/xml

echo "Creating bigfile"
xmllint --xinclude --postvalid --noent --output ay_bigfile.xml autoyast.xml || _exit_on_error "Failed to create bigfile"
sed -i 's:\(fileref="\)img/:\1:g' ay_bigfile.xml



cd ${CHECKOUT_DIR}/doc

mkdir -p ${CHECKOUT_DIR}/doc/docteam

echo "Creating PDF"
daps -e "$ENVFILE" --builddir ${CHECKOUT_DIR}/doc/docteam color-pdf

echo "Creating HTML"
daps -e "$ENVFILE" --builddir ${CHECKOUT_DIR}/doc/docteam html

echo "Creating Source tarballs"
daps -e "$ENVFILE" --builddir ${CHECKOUT_DIR}/doc/docteam package-src