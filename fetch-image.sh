#!/usr/bin/env bash

while [[ $# -gt 0 ]]; do
i="$1"

case $i in
    -i|--image)
    IMAGE="$2"
    shift # past argument
    shift # past value
    ;;
    -i=*|--image=*)
    IMAGE="${i#*=}"
    shift # past argument=value
    ;;
    *)
    shift # past argument
    ;;
esac
done

if [ -z $IMAGE ]; then
    echo "ERROR: Image is not specified"
    echo "Usage: ${0##*/} -i ubuntu-22.04-server-cloudimg-amd64"
    exit 1
fi

wget http://cloud-images.ubuntu.com/releases/jammy/release/$IMAGE.img --output-document=$IMAGE-orig.img

# Resize the image to fit a container image
export LIBGUESTFS_BACKEND=direct
qemu-img create -f qcow2 -o preallocation=metadata ./$IMAGE.img 18G
virt-resize --expand /dev/sda1 ./$IMAGE-orig.img ./$IMAGE.img
#rm $IMAGE-orig.img

exit 0
