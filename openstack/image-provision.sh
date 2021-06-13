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
    -a|--archive)
    ARCHIVE="$2"
    shift # past argument
    shift # past value
    ;;
    -a=*|--archive=*)
    ARCHIVE="${i#*=}"
    shift # past argument=value
    ;;
    *)
    shift # past argument
    ;;
esac
done

if [ -z $IMAGE ]; then
    echo "ERROR: Image is not specified"
    echo "Usage: ${0##*/} -i ubuntu-18.04-minimal-cloudimg-amd64.img -a /opt/swm/1.0.1/swm-1.0.1-worker.tar.gz"
    exit 1
fi

if [ -z $ARCHIVE ]; then
    echo "ERROR: Archive is not specified"
    echo "Usage: ${0##*/} -i ubuntu-18.04-minimal-cloudimg-amd64.img -a /opt/swm/1.0.1/swm-1.0.1-worker.tar.gz"
    exit 1
fi

mountpoint=${IMAGE##*/}
mountpoint=/mnt/${mountpoint%.*}

export LIBGUESTFS_BACKEND=direct

mkdir -p ${mountpoint} > /dev/null 2>&1

for i in {1..2}; do
    umount -f ${mountpoint}/sys         > /dev/null 2>&1;
    umount -f ${mountpoint}/dev/pts     > /dev/null 2>&1;
    umount -f ${mountpoint}/dev         > /dev/null 2>&1;
    umount -f ${mountpoint}/proc        > /dev/null 2>&1;

    umount -f ${mountpoint}             > /dev/null 2>&1;
    guestunmount ${mountpoint}          > /dev/null 2>&1;
done

guestmount -a $IMAGE -i --rw ${mountpoint}

mount --bind /sys       ${mountpoint}/sys
mount --bind /dev       ${mountpoint}/dev
mount --bind /dev/pts   ${mountpoint}/dev/pts
mount --bind /proc      ${mountpoint}/proc

NONCE=$(date '+%s')
mkdir -p /tmp/${NONCE}
tar -C /tmp/${NONCE} -xvzf ${ARCHIVE} --strip-components 1
sed -i '/exit.*/d' /tmp/${NONCE}/scripts/swm.env
source /tmp/${NONCE}/scripts/swm.env > /dev/null 2>&1
rm -rf /tmp/${NONCE}

cp $ARCHIVE ${mountpoint}/opt/

cat << EOF | sudo chroot ${mountpoint}
### BEGIN PROVISION IMAGE IN CHROOT

mkdir -p /opt/data
chmod 777 /opt/data

mkdir -p /run/resolvconf
mkdir -p /run/systemd/resolve
echo "nameserver 8.8.8.8" > /run/resolvconf/resolv.conf
echo "nameserver 8.8.8.8" > /run/systemd/resolve/stub-resolv.conf

echo "127.0.0.1       localhost.localdomain localhost" > /etc/hosts
echo "127.0.0.1       openstack.skyworkflows.com openstack" >> /etc/hosts

apt-get --yes update
apt-get --yes autoremove

apt-get --yes --purge remove ufw
apt-get --yes --purge remove at snapd lvm2 lxcfs open-iscsi policykit-1

apt-get --yes install locales
locale-gen en_US.UTF-8

apt-get --yes install linux-modules-extra-*-generic # nfsd module
apt-get --yes install nfs-kernel-server nfs-common
apt-get --yes install nfs-kernel-server nfs-common
update-rc.d nfs-kernel-server enable

apt-get --yes install docker docker.io
echo 'DOCKER_OPTS="-H tcp://127.0.0.1:6000"' >> /etc/default/docker

### END PROVISION IMAGE IN CHROOT
EOF

cat << EOF | sudo chroot ${mountpoint}
### BEGIN INSTALL SWM IN CHROOT

rm -rf ${SWM_ROOT}/${SWM_VERSION}

mkdir -p ${SWM_ROOT}/${SWM_VERSION}
mkdir -p ${SWM_SPOOL}

tar -C ${SWM_ROOT} -xvzf /opt/${ARCHIVE}

${SWM_ROOT}/${SWM_VERSION}/scripts/setup.linux -p ${SWM_ROOT} -c ${SWM_ROOT}/${SWM_VERSION}/priv/setup/setup-config.linux

### END INSTALL SWM IN CHROOT
EOF

cat << EOF | sudo chroot ${mountpoint}
### BEGIN POST CONFIGURATION SWM IN CHROOT

systemctl enable docker
systemctl enable swm

### END POST CONFIGURATION SWM IN CHROOT
EOF

# Pull default docker image for tests purposes
docker pull ubuntu:18.04

umount -f ${mountpoint}/sys
umount -f ${mountpoint}/dev/pts
umount -f ${mountpoint}/dev
umount -f ${mountpoint}/proc

sync

guestunmount --retry=10 ${mountpoint}

echo "Image provisioning with $IMAGE has finished"
