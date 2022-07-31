OpenStack In Vagrant Box
========================

The reporitory contains configuration files needed to spawn OpenStack in a single Vagrant box.
OpenStack services are started in docker containers via kolla-ansible.

Requirements
------------

* Vagrant >= 2.2.19


Run a box
---------

### Start VM
```console
vagrant up
```

### Halt
```console
vagrant halt
```

### Destroy
```console
vagrant destroy
```

### Remount sync directory after box restart
```console
vagrant reload
```

### Simple test of openstack setup
Run command inside OpenStack's box:
```console
source /etc/kolla/admin-openrc.sh
cd /home/vagrant/sync
openstack stack create -e heat-environment -t heat-template.yaml demo-stack
```

Prepare compute image for OpenStack development setup
-----------------------------------------------------

* Prepare SWM worker release tarball and copy it to current directory:

For development setup:
```console
cd swm-core
make release
./scripts/setup.linux -t -a
cp _build/packages/swm-${SWM_VERSION}-worker.tar.gz ../openstack-box/
```

For regular setup:
```console
cp /opt/swm/swm-${SWM_VERSION}-worker.tar.gz openstack-box/swm-worker.tar.gz
```

* Download image that will be used for compute VMs to openstack-box:
```console
cd openstack-box
wget http://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img
```

* Provision the image with swm:
```console
vagrant ssh
sudo bash
cd /home/vagrant/sync
IMAGE=ubuntu-22.04-minimal-cloudimg-amd64
./image-provision.sh -i ${IMAGE}.img -a swm-worker.tar.gz
```

* Customize for development purposes (if needed):
```console
sudo bash
./image-mount.sh -i ${IMAGE}.img
mkdir /mnt/${IMAGE}/root/.ssh
chmod 700 /mnt/${IMAGE}/root/.ssh
vim /mnt/${IMAGE}/root/.ssh/authorized_keys  # add public key
chmod 600 /mnt/${IMAGE}/root/.ssh/authorized_keys
./image-umount.sh -i ${IMAGE}.img
```

* Load the prepared image to OpenStack:
```console
source /etc/kolla/admin-openrc.sh
openstack image create --public --disk-format qcow2 --container-format bare --file ${IMAGE}.img ubuntu-22.04
```


Troubleshooting
---------------
* Image format type can be found with "file -k".
* Use "docker ps -a" to get all kolla containers, see their health status.
* OpenStack logs inside the box can be found in /var/lib/docker/volumes/kolla_logs/_data/
* The compute node image must run docker on port 6000 if the job is going to run in docker containers.
