#!/bin/sh
# Anas Nashif <nashif@suse.de>
#
# $Id$
#


. /etc/rc.status

usage() {
cat << EOF
update_inst-sys.sh: 
Update cramfs image with files y2update image

Anas Nashif <nashif@suse.de>, 2003 (c)

-h:                 This help
-r: <file name>:    root image (from boot/ on CDs)
-y: <file name>:    y2update image 
-o: <file name>:    Output cramfs image (default: /tmp/root)


EOF
exit 0

}


output=/tmp/root 
while [ "$#" -gt 0 ]
do
    case "$1" in
        -r) options="$options $1"
			root_image=$2
			shift
			;;
        -o) options="$options $1"
			output=$2
			shift
			;;
        -y) options="$options $1"
            y2update="$2"
            shift
            ;;
        -h) usage;
			;;
    esac
    shift
done





if [ -z $root_image -a -z $y2update ]; then
    echo "$0: Missing file names, exiting..."
    exit 1
else
	if [ ! -f $root_image ]; then
		echo "$0: can't find $root_image"
		exit 1
	fi
	if [ ! -f $y2update ]; then
		echo "$0: can't find $y2update"
		exit 1
	fi

fi


echo -n "Creating temp. directory"
tmp_dir=`mktemp -qd /tmp/tmp.XXXXXX`
if [ $? -ne 0 ]; then
	rc_status -v
    echo "$0: Can't create temp dir, exiting..."
    exit 1
fi
rc_status -v

echo -n "Creating temp. mount directory for root image"
root_dir=`mktemp -qd $tmp_dir/instsys.XXXXXX`
if [ $? -ne 0 ]; then
	rc_status -v
    echo "$0: Can't create temp mount dir, exiting..."
    exit 1
fi
rc_status -v

echo -n "Creating temp. mount directory for y2update image"
y2update_dir=`mktemp -qd $tmp_dir/y2update.XXXXXX`
if [ $? -ne 0 ]; then
	rc_status -v
    echo "$0: Can't create temp mount dir, exiting..."
    exit 1
fi
rc_status -v


echo -n "Mounting images"
cp  $y2update $tmp_dir

y2update_file="y2update"
zcat $y2update > $tmp_dir/$y2update_file
mount -oloop $root_image $root_dir
mount -oloop  $tmp_dir/$y2update_file $y2update_dir
if [ $? -ne 0 ]; then
	rc_status -v
	echo
    echo "$0: Can't mount images, exiting..."
	umount $root_dir
    exit 1
fi
rc_status -v

mkdir -p $tmp_dir/inst-sys
echo -n "Copying contents of cramfs image...."
(
	cd $root_dir
	tar cf - . |  (cd  $tmp_dir/inst-sys;  tar xf - )
)
if [ $? -ne 0 ]; then
	rc_status -v
    echo "$0: Can't copy cramfs image, exiting..."
    exit 1
fi
rc_status -v

echo -n "Updating root image with new files...."
(
	cd $y2update_dir
	tar cf - . |  (cd  $tmp_dir/inst-sys/usr/share/YaST2;  tar xf - )
)

if [ $? -ne 0 ]; then
	rc_status -v
    echo "$0: Can't copy files to image, exiting..."
    exit 1
fi
rc_status -v



umount $y2update_dir $root_dir

echo -n "Creating cramfs image...."
mkfs.cramfs $tmp_dir/inst-sys $output
if [ $? -ne 0 ]; then
	rc_status -v
    echo "$0: Can't create cramfs image, exiting..."
    exit 1
fi
rc_status -v


echo -n "Remove temporary files in $tmp_dir? (Y/n)"
read answer
case "$answer" in
	y|Y|yes)
		rm -rf $tmp_dir
		;;
	*) echo "Not deleting";;
esac


