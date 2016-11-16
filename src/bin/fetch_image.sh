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

case "$LOCATION" in
    # catch http, https, ftp and tftp
    http:*|https:*|ftp:*|tftp:*)
        wget --no-check-certificate -O - $LOCATION 2>/dev/null | tar xfz - -C /mnt
        ;;
    nfs:*)
        # FIXME
        mkdir -p /tmp/image_mount
        ;;
    file:*)
        LOCATION=`echo $LOCATION|sed 's|file://||'`
        if [ ! -e "$LOCATION" ]; then
            DEVICE=`grep ^Device: /etc/install.inf | awk '{ print $2 }'`
            mkdir -p /tmp/instsource
            mount /dev/$DEVICE /tmp/instsource
            tar xfz /tmp/instsource/$LOCATION -C /mnt
            umount /tmp/instsource
        else
            tar xfz /tmp/instsource/$LOCATION -C /mnt
        fi
        ;;
esac

mv /tmp/fstab /mnt/etc
