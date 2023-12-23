#!/usr/bin/env bash

# The script is executed after ssh to the running box
# It serves development purposes to update the existing
# image with new swm worker files.

set -exuo pipefail

while getopts i:v: flag; do
    case "${flag}" in
        i) IMAGE=${OPTARG};;
        v) SWM_VERSION=${OPTARG};;
    esac
done

function usage() {
    echo $1
    echo "Usage: ${0##*/} -i ubuntu-22.04-minimal-cloudimg-amd64 -v 0.2.0"
}

if [ -z ${IMAGE:-} ]; then
    usage "Error: Image is not set"
    exit 1
fi
if [ -z ${SWM_VERSION:-} ]; then
    usage "Error: SWM version is not set"
    exit 1
fi

[[ $UID = 0 ]] || exec sudo $0 "$@"
cd /home/vagrant/sync

./image-mount.sh -i ${IMAGE}.img
rm -fr /mnt/${IMAGE}/opt/swm/${SWM_VERSION}
mkdir -p /mnt/${IMAGE}/opt/swm
tar -C /mnt/${IMAGE}/opt/swm -xvzf ./swm-worker.tar.gz
./image-umount.sh -i ${IMAGE}.img

exit 0
