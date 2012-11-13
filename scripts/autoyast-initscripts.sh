#! /bin/sh
# Copyright (c) 2012 SUSE Linux AG, Nuernberg, Germany.
# All rights reserved.
#
# Author: Thomas Fehr
# Please send feedback to http://www.suse.de/feedback/
#


LOG_DIR="/var/adm/autoinstall/logs"
SCRIPT_DIR="/var/adm/autoinstall/scripts"
INITSCRIPT_DIR="/var/adm/autoinstall/init.d"

if [ ! -d "$INITSCRIPT_DIR" ]; then
    exit 1
fi

for script in  `find $INITSCRIPT_DIR -type f`; do
    CONTINUE=1
done

if [ -z "$CONTINUE" ]; then
    exit 0
fi

for script in  `find $INITSCRIPT_DIR -type f |sort`; do
    echo -n "Executing AutoYaST script: $script"
    BASENAME=`basename $script`
    sh -x $script > $LOG_DIR/$BASENAME.log 2>&1
    mv $script $SCRIPT_DIR
done

systemctl disable autoyast-initscript.service
