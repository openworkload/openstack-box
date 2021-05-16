SWM OpenStack Development Setup
===============

Requirements
------------

* Vagrant 1.9.5 or newer


Run a box
---------

### Prepare
```console
    $ vagrant plugin install vagrant-vbguest
```

### Run
```console
    $ vagrant up
```

### Halt
```console
    $ vagrant halt
```

### Destroy
```console
    $ vagrant destroy
```

### Remount sync directory after box restart
```console
    $ vagrant reload
```

### Simple test of openstack setup
Run command inside OpenStack's box:
```console
    $ source /etc/kolla/admin-openrc.sh
    $ cd /home/vagrant/sync
    $ openstack stack create -e heat-environment -t heat-template.yaml demo-stack
```
Prepare compute image for OpenStack development setup
---------------------

* Prepare SWM worker release tarball and copy it to directory swm-util/openstack:
-- For development setup:
```console
    $ make release
    $ ./scripts/setup.linux -t -a
    $ cp _build/packages/swm-${SWM_VERSION}-worker.tar.gz ../swm-util/openstack/
```
-- For regular setup:
```console
    $ cp /opt/swm/swm-${SWM_VERSION}-worker.tar.gz swm-util/openstack/
```

* Download image that will be used for compute VMs to swm-util/openstack:
```console
    $ IMAGE=ubuntu-21.04-minimal-cloudimg-amd64
    $ cd swm-util/openstack
    $ wget http://cloud-images.ubuntu.com/minimal/releases/hirsute/release/${IMAGE}.img
```

* Provision the image with swm:
```console
    $ vagrant ssh
    $ cd sync
    $ sudo bash
    $ ./image-provision.sh -i ${IMAGE}.img -a swm-worker.tar.gz
```

* Customize for development purposes (if needed):
```console
    $ ./image-mount.sh -i ${IMAGE}.img
    $ mkdir /mnt/${IMAGE}/home/${USER}/.ssh
    $ chmod 700 /mnt/${IMAGE}/home/${USER}/.ssh
    $ cat ~/.ssh/id_rsa.pub >> /mnt/${IMAGE}/home/${USER}/.ssh/authorized_keys
    $ chmod 600 /mnt/${IMAGE}/home/${USER}/.ssh/authorized_keys
    $ echo "${USER} ALL = (ALL) ALL" >> /mnt/${IMAGE}/etc/sudoers
    $ ./image-umount.sh -i ${IMAGE}.img
```

* Load the prepared image to OpenStack:
```console
    $ source /etc/kolla/admin-openrc.sh
    $ openstack image create --public --disk-format qcow2 --container-format bare --file ${IMAGE}.img ubuntu-21.04
```
   
Image format type can be found with "file -k". 
Note that the compute node image must run docker on port 6000 if the job is going to run in docker containers.


Troubleshooting
---------------
```console
    $ vagrant reload
    $ vagrant vbguest
    $ vagrant provision
    $ vagrant ssh
    $> sudo reboot
    $> docker restart nova_libvirt
    $> docker restart keepalived
```

OpenStack logs inside the box can be found in /var/lib/docker/volumes/kolla_logs/_data/
