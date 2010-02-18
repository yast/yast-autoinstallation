#!/bin/sh
# Copyright (c) 2010 SUSE Linux AG, Nuernberg, Germany.
# All rights reserved.
#
# Author: Uwe Gansert
# Please send feedback to uwe.gansert@suse.de


mv /mnt/etc/fstab /tmp/
LOCATION=$1

if [ -f /tmp/fetch_image ]; then
    /bin/bash -x /tmp/fetch_image > /tmp/ayast_image.log 2>&1
    exit $?
fi;

# catch http, https, ftp and tftp
if [[ "x$LOCATION" =~ ^x..?tp ]]; then
    wget -O - $LOCATION 2>/dev/null | tar xfz - -C /mnt
fi;

if [[ "$LOCATION" =~ ^nfs ]]; then
# FIXME
    mkdir -p /tmp/image_mount
fi;

if [[ "x$LOCATION" =~ ^xfile ]]; then
    LOCATION=`echo $LOCATION|sed 's|file://||'`;
    if [ ! -e "$LOCATION" ]; then
        DEVICE=`grep ^Device: /etc/install.inf | awk '{ print $2 }'`
        mkdir -p /tmp/instsource
        mount /dev/$DEVICE /tmp/instsource
        tar xfz /tmp/instsource/$LOCATION -C /mnt
        umount /tmp/instsource
    else
        tar xfz /tmp/instsource/$LOCATION -C /mnt
    fi;
fi;


mv /tmp/fstab /mnt/etc

