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
./scripts/setup-skyport-dev.linux
cp _build/packages/swm-${SWM_VERSION}-worker.tar.gz ../openstack-box/swm-worker.tar.gz
```

* For regular setup replace the last command from above to:
```console
cp /opt/swm/swm-${SWM_VERSION}-worker.tar.gz openstack-box/swm-worker.tar.gz
```

### Download image that will be used for compute VMs to openstack-box:
```console
cd openstack-box
wget http://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img
```

### Provision the image with swm:
```console
vagrant ssh
sudo bash
cd /home/vagrant/sync
IMAGE=ubuntu-22.04-minimal-cloudimg-amd64
./image-provision.sh -i ${IMAGE}.img -a swm-worker.tar.gz
```

### Customize for development purposes (if needed):
```console
sudo bash
cd /home/vagrant/sync
./image-mount.sh -i ${IMAGE}.img
mkdir /mnt/${IMAGE}/root/.ssh
chmod 700 /mnt/${IMAGE}/root/.ssh
vim /mnt/${IMAGE}/root/.ssh/authorized_keys  # add public key
chmod 600 /mnt/${IMAGE}/root/.ssh/authorized_keys
chroot /mnt/${IMAGE} "apt-get update; apt-get install vim mc"
./image-umount.sh -i ${IMAGE}.img
```

### Load the prepared image to OpenStack (as vagrant user):
```console
cd /home/vagrant/sync
source /etc/kolla/admin-openrc.sh
openstack image create --public --disk-format qcow2 --container-format bare --file ${IMAGE}.img ubuntu-22.04
```


## Troubleshooting

* Image format type can be found with "file -k".
* Use "docker ps -a" to get all kolla containers, see their health status.
* OpenStack logs inside the box can be found in /var/lib/docker/volumes/kolla_logs/_data/
* The compute node image must run docker on port 6000 if the job is going to run in docker containers.
