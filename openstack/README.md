SkyWM OpenStack Development Setup
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

### Simple test of openstack setup
Run command inside OpenStack's box:
    $ source /etc/kolla/admin-openrc.sh
    $ cd /home/vagrant/sync
    $ openstack stack create -e heat-environment -t heat-template.yaml demo-stack

Prepare compute image for OpenStack development setup
---------------------

* Prepare SWM worker release tarball and copy it to directory swm-util/openstack:
    - For development setup:
        $ make release
        $ ./scripts/setup.linux -t -a
        $ cp _build/packages/swm-${SWM_VERSION}-worker.tar.gz ../swm-util/openstack/
    - For regular setup:
        $ cp /opt/swm/swm-${SWM_VERSION}-worker.tar.gz swm-util/openstack/

* Download image that will be used for compute VMs to swm-util/openstack:
    $ cd swm-util/openstack
    $ wget http://cloud-images.ubuntu.com/minimal/releases/hirsute/release/ubuntu-21.04-minimal-cloudimg-amd64.img

* Run command:
    $ vagrant ssh
    $ cd sync
    $ sudo bash
    $ ./image-provision.sh -i ubuntu-21.04-minimal-cloudimg-amd64.img -a swm-worker.tar.gz

* Load the prepared image to OpenStack:
    $ source /etc/kolla/admin-openrc.sh
    $ openstack image create --public --disk-format qcow2 --container-format bare --file ubuntu-21.04-minimal-cloudimg-amd64.img ubuntu-21.04

    Image format type can be found with "file -k".


Note that the compute node image must run docker on port 6000
     if the job is going to run in docker containers.


Troubleshooting
---------------
    $ vagrant reload
    $ vagrant vbguest
    $ vagrant provision
    $ vagrant ssh
    $> sudo reboot
    $> docker restart nova_libvirt
    $> docker restart keepalived

    OpenStack logs inside the box can be found in /var/lib/docker/volumes/kolla_logs/_data/
