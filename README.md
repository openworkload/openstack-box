# OpenStack In Vagrant Box

The reporitory contains configuration files needed to spawn OpenStack in a single Vagrant box.
OpenStack services are started in docker containers via kolla-ansible.

## Requirements

* Vagrant >= 2.2.19
* VirtualBox (run `VBoxManage --version` to ensure it works)
* 32GB of memory for virtual machines
* VirtualBox allows the box IP address configured in Vagrantfile. For example to allow all addresses the following commands can be executed:
```console
sudo mkdir /etc/vbox/
sudo chmod 644 /etc/vbox/networks.conf
sudo echo '* 0.0.0.0/0 ::/0' > /etc/vbox/networks.conf
```

## Run a box

### Start VM
```console
vagrant up
```
or if you have several providers or not sure what provider is default:
```console
vagrant up --provider=virtualbox
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
```console
vagrant ssh
source /etc/kolla/admin-openrc.sh
cd /home/vagrant/sync
openstack stack create -e heat-environment -t stack-example.yaml test
```

## Prepare compute image for OpenStack development setup

### Prepare SWM worker release tarball and copy it to current directory:

* For development setup:
```console
sudo mkdir /opt/swm
sudo chown $(id -u) /opt/swm
make cr
cd swm-core
make release
SWM_VERSION=0.2.0
./scripts/setup-skyport-dev.linux  # if not already set up, otherwise "scripts/setup.linux -a -t"
cp _build/packages/swm-${SWM_VERSION}-worker.tar.gz ../openstack-box/swm-worker.tar.gz
```

* For regular setup replace the last command from above to:
```console
cp /opt/swm/swm-${SWM_VERSION}-worker.tar.gz openstack-box/swm-worker.tar.gz
```

### Prepare VM image that will be used for compute VMs in the Openstack
### Download the image:
```console
cd openstack-box
wget http://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img orig.img
```
#### Resize the root disk of the downloaded image if needed (so it can fit huge container images):
```console
export LIBGUESTFS_BACKEND=direct
qemu-img create -f qcow2 -o preallocation=metadata ./ubuntu-22.04-minimal-cloudimg-amd64.img 16G
virt-resize --expand /dev/sda1 ./orig.img ./ubuntu-22.04-minimal-cloudimg-amd64.img
rm -f ./orig.img
```
#### Get some info about the image partitions:
```console
export LIBGUESTFS_BACKEND=direct
qemu-img info ./ubuntu-22.04-minimal-cloudimg-amd64.img
virt-filesystems --long -h --all -a ./ubuntu-22.04-minimal-cloudimg-amd64.img
```

### Provision the image with swm:
#### New setup:
```console
vagrant ssh
sudo bash
cd /home/vagrant/sync
IMAGE=ubuntu-22.04-minimal-cloudimg-amd64
./image-provision.sh -i ${IMAGE}.img -a swm-worker.tar.gz
```
#### Update:
```console
vagrant ssh
sudo bash
cd /home/vagrant/sync
IMAGE=ubuntu-22.04-minimal-cloudimg-amd64
SWM_VERSION=0.2.0
./image-mount.sh -i ${IMAGE}.img
rm -fr /mnt/${IMAGE}/opt/swm/${SWM_VERSION}
tar -C /mnt/${IMAGE}/opt/swm -xvzf /home/vagrant/sync/swm-worker.tar.gz
./image-umount.sh -i ${IMAGE}.img
```

### Customize for development purposes (if needed):
```console
sudo bash
cd /home/vagrant/sync
IMAGE=ubuntu-22.04-minimal-cloudimg-amd64
./image-mount.sh -i ${IMAGE}.img
mkdir /mnt/${IMAGE}/root/.ssh
chmod 700 /mnt/${IMAGE}/root/.ssh
vim /mnt/${IMAGE}/root/.ssh/authorized_keys  # add public key
chmod 600 /mnt/${IMAGE}/root/.ssh/authorized_keys
./image-umount.sh -i ${IMAGE}.img
```

### Load the prepared image to OpenStack (as vagrant user):
```console
cd /home/vagrant/sync
source /etc/kolla/admin-openrc.sh
IMAGE=ubuntu-22.04-minimal-cloudimg-amd64
openstack image create --public --disk-format qcow2 --container-format bare --file ${IMAGE}.img ubuntu-22.04
```


## Troubleshooting
* Use "docker ps -a" to get all kolla containers, see their health status
* OpenStack logs inside the box can be found in /var/lib/docker/volumes/kolla_logs/_data/
* The compute node image must run docker that listens to local port 6000 if the job is going to run in docker containers
