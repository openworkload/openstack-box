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
    echo "Usage: ${0##*/} -i ubuntu-21.04-minimal-cloudimg-amd64.img"
    exit 1
fi


mountpoint=${IMAGE##*/}
mountpoint=/mnt/${mountpoint%.*}

export LIBGUESTFS_BACKEND=direct

umount -f ${mountpoint}/sys
umount -f ${mountpoint}/dev/pts
umount -f ${mountpoint}/dev
umount -f ${mountpoint}/proc

sync

guestunmount --retry=10 ${mountpoint}

echo "Image is unmounted from ${mountpoint}"
