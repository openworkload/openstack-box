SkyWM OpenStack
===============

Requirements
------------

Vagrant 1.9.5 or newer


Run a box
---------

### Prepare
    $ vagrant plugin install vagrant-vbguest

### Run
    $ vagrant up

### Halt
    $ vagrant halt

### Destroy
    $ vagrant destroy

### Remount sync directory after box restart
    $ vagrant reload

### Test
Run command inside OpenStack's box:
    $ source /etc/kolla/admin-openrc.sh
    $ cd /home/vagrant/sync
    $ openstack stack create -e heat-environment -t heat-template.yaml demo-stack

Prepare compute image
---------------------

* Prepare SWM release tarball and copy it to directory swm-tests/openstack:
    $ cp /opt/swm/swm-${SWM_VERSION}-worker.tar.gz swm-tests/openstack/

* Download image that will be used for compute VMs to swm-tests/openstack:
    $ cd swm-tests/openstack
    $ wget http://cloud-images.ubuntu.com/minimal/releases/xenial/release-20180705/ubuntu-16.04-minimal-cloudimg-amd64-disk1.img

* Run command:
    $ sudo bash
    $ ./image-provision.sh -i ubuntu-16.04-minimal-cloudimg-amd64-disk1.img -a swm-${SWM_VERSION}-worker.tar.gz

* Load the prepared image to OpenStack:
    $ vagrant ssh
    $ openstack image create --public --disk-format qcow2 --container-format bare --file ubuntu-16.04-minimal-cloudimg-amd64-disk1.img ubuntu-16.04

    Image format type can be found with "file -k".


Note that the compute node image must run docker on port 6000
     if the job is going to run in docker containers.


Troubleshooting
---------------
    $ vagrant vbguest
    $ vagrant provision
    $ vagrant ssh
    $> sudo reboot
    $> docker restart nova_libvirt
    $> docker restart keepalived

    OpenStack logs inside the box can be found in /var/lib/docker/volumes/kolla_logs/_data/
