#!/usr/bin/env bash

while [[ $# -gt 0 ]]
do
i="$1"

case $i in
    -i|--image)
    IMAGE="$2"
    shift # past argument
    shift # past value
    ;;
    *)
    shift # past argument
    ;;
esac
done

if [ -z $IMAGE ];
then
    echo "Error: Image is not specified"
    echo "Usage: ${0##*/} -i ubuntu-18.04-server-cloudimg-amd64.img"
    exit 1
fi


umount_timeout=10
mountpoint=${IMAGE##*/}
mountpoint=/mnt/${mountpoint%.*}

export LIBGUESTFS_BACKEND=direct

mkdir -p ${mountpoint} > /dev/null 2>&1

echo "Ensure mount point is unmounted: ${mountpoint}"
for i in {1..2};
do
    timeout $umount_timeout umount -f ${mountpoint}/sys         > /dev/null 2>&1;
    timeout $umount_timeout umount -f ${mountpoint}/dev/pts     > /dev/null 2>&1;
    timeout $umount_timeout umount -f ${mountpoint}/dev         > /dev/null 2>&1;
    timeout $umount_timeout umount -f ${mountpoint}/proc        > /dev/null 2>&1;

    timeout $umount_timeout umount -f ${mountpoint}             > /dev/null 2>&1;
    timeout $umount_timeout guestunmount ${mountpoint}          > /dev/null 2>&1;
done

echo "Mount image $IMAGE at ${mountpoint} ..."
guestmount -a $IMAGE -i --rw ${mountpoint}

mount --bind /sys       ${mountpoint}/sys
mount --bind /dev       ${mountpoint}/dev
mount --bind /dev/pts   ${mountpoint}/dev/pts
mount --bind /proc      ${mountpoint}/proc

echo "Image is mounted"
