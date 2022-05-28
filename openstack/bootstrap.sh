#!/usr/bin/env bash
#
# This script is meant to be run in provisioning stage by vagrant.
# This script configure OS environment for openstack, install docker
# git clone kolla and kolla-ansible repos, deploy openstack and
# initialize demo instance in it.

set -e

function fix_dns {
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
}

function initialize {
    fix_dns

    if [[ "$(systemctl is-enabled firewalld)" == "enabled" ]]; then
        systemctl stop firewalld
        systemctl disable firewalld
    fi

    yum -y install iptables-services

    cat > /etc/sysconfig/iptables <<-EOF
*filter
-A FORWARD -s 172.28.128.0/24 -j ACCEPT
-A FORWARD -d 172.28.128.0/24 -j ACCEPT
COMMIT
*nat
-A POSTROUTING -s 172.28.128.0/24 -o eth0 -j MASQUERADE
COMMIT
EOF

    systemctl enable iptables
    systemctl start iptables

    if [[ "$(getenforce)" == "Enforcing" ]]; then
        sed -i -r "s,^SELINUX=.+$,SELINUX=permissive," /etc/selinux/config
        setenforce permissive
    fi

    cat > /etc/hosts <<-EOF
127.0.0.1       localhost localhost.localdomain localhost4 localhost4.localdomain4
::1             localhost localhost.localdomain localhost6 localhost6.localdomain6
172.28.128.2    openstack openstack.openworkload.com
EOF

    # Configure open vSwitch external bridge
    cat > /etc/udev/rules.d/90-br-ex.rules <<-EOF
ACTION=="add", SUBSYSTEM=="net", KERNEL=="br-ex", RUN+="/sbin/ifconfig br-ex 172.28.128.2/24 up"
EOF
    udevadm control --reload-rules

    yum -y install epel-release
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7

    yum -y install MySQL-python mariadb
    yum -y install git tmux vim-enhanced
    yum -y install python-pip python-devel
    yum -y install gcc openssl-devel libffi-devel libxml2-devel libxslt-devel
    yum -y install htop net-tools bridge-utils openvswitch tcpdump
    yum -y install mlocate

    # Install guestmount for image provision
    yum -y install libguestfs-tools
    systemctl disable libvirtd
}

function configure_docker {
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    # Also upgrade device-mapper here because of:
    # https://github.com/docker/docker/issues/12108
    # Upgrade lvm2 to get device-mapper installed
    yum -y install docker-ce docker-ce-cli containerd.io lvm2 device-mapper

    grep -q MountFlags /usr/lib/systemd/system/docker.service &&
        sed -i 's|^MountFlags=.*|MountFlags=shared|' /usr/lib/systemd/system/docker.service ||
        sed -i '/\[Service\]/a MountFlags=shared' /usr/lib/systemd/system/docker.service

    usermod -aG docker vagrant

    systemctl daemon-reload
    systemctl enable docker
    systemctl start docker
}

function configure_kolla {

    #rpm -e python-ipaddress pyparsing --nodeps
    #rpm -e python-ipaddress --nodeps
    pip install --upgrade pyparsing

    pip install --upgrade pip
    pip install --upgrade setuptools
    pip install --upgrade cmd2
    #pip install --upgrade ipaddress

    pip install --upgrade "ansible==2.3" tox

    # Otherwise installation of python-openstackclient fails
    rpm -e PyYAML atomic-registries || true

    pip install --upgrade "python-openstackclient==3.12.0"
    pip install --upgrade "python-neutronclient==6.5.0"
    pip install --upgrade "python-heatclient==1.12.0"
    pip install --upgrade "python-cloudkittyclient==1.1.0"
    pip install --upgrade "python-ceilometerclient==2.9.0"
    pip install --upgrade "gnocchiclient==6.0.0"
    pip install --upgrade "openstacksdk==0.17.2"

    # Workaround for https://github.com/docker/docker-py/issues/1353
    #pip uninstall -y docker docker-py
    #pip install docker

    cd /home/vagrant
    rm -fr kolla
    git clone http://github.com/openstack/kolla
    cd kolla
    git checkout stable/pike

    cd /home/vagrant
    rm -fr kolla-ansible
    git clone http://github.com/openstack/kolla-ansible
    cd kolla-ansible
    git checkout stable/pike

    pip install /home/vagrant/kolla-ansible
    pip install /home/vagrant/kolla

    tox -c /home/vagrant/kolla/tox.ini -e genconfig

    cp -r /home/vagrant/kolla-ansible/etc/kolla/ /etc/kolla
    cp -r /home/vagrant/kolla/etc/kolla/* /etc/kolla

    yum install python-ipaddress -y # otherwise the module cannot be found by the next tool
    /home/vagrant/kolla-ansible/tools/generate_passwords.py

    ### Set release version
    sed -i -r "s,^[# ]*openstack_release:.+$,openstack_release: \"pike\"," /etc/kolla/globals.yml
    ### Set network interfaces
    # Interface for API,  will be used by OpenStack to bind services on it
    sed -i -r "s,^[# ]*network_interface:.+$,network_interface: \"eth1\"," /etc/kolla/globals.yml
    # Interface for networking, will be user by OpenStack neutron service
    sed -i -r "s,^[# ]*neutron_external_interface:.+$,neutron_external_interface: \"eth1\"," /etc/kolla/globals.yml
    ### Configure IP addresses
    # IP address of 'network_interface', will be used by OpenStack to bind services on it
    sed -i -r "s,^[# ]*kolla_internal_vip_address:.+$,kolla_internal_vip_address: \"172.28.128.254\"," /etc/kolla/globals.yml
    # Public IP address, which could be exposed to the world, by example public IP in amazon or azure
    sed -i -r "s,^[# ]*kolla_external_vip_address:.+$,kolla_external_vip_address: \"172.28.128.254\"," /etc/kolla/globals.yml
    ### Enable services
    sed -i -r "s,^[# ]*enable_gnocchi:.+$,enable_gnocchi: \"yes\"," /etc/kolla/globals.yml
    sed -i -r "s,^[# ]*enable_ceilometer:.+$,enable_ceilometer: \"yes\"," /etc/kolla/globals.yml
    sed -i -r "s,^[# ]*enable_cloudkitty:.+$,enable_cloudkitty: \"yes\"," /etc/kolla/globals.yml
    ### Configure services
    echo 'cloudkitty_collector_backend: "gnocchi"' >> /etc/kolla/globals.yml
    ### Reduce # of threads
    echo 'openstack_service_workers: "2"'>> /etc/kolla/globals.yml
    echo 'openstack_service_rpc_workers: "2"' >> /etc/kolla/globals.yml

    # Use QEMU hypervisor instead of KVM hypervisor for nested virtualization
    mkdir -p /etc/kolla/config/nova/
    cat > /etc/kolla/config/nova/nova-compute.conf <<EOF
[libvirt]
virt_type=qemu
cpu_mode=none

[conductor]
workers = 8

[DEFAULT]
debug=true
cpu_allocation_ratio=1024.0
ram_allocation_ratio=1024.0
disk_allocation_ratio=1024.0
EOF

    # Add nove_metadata_ip for neutron metadata agent
    # without that neutron metadata doesn't know where is nova api
    mkdir -p /etc/kolla/config/neutron/
    cat > /etc/kolla/config/neutron/neutron-metadata-agent.conf <<EOF
[DEFAULT]
nova_metadata_ip="{{ kolla_internal_vip_address }}"
EOF

    mkdir -p /usr/share/kolla
    chown -R vagrant: /etc/kolla /usr/share/kolla
}

function openstack_deploy {
    kolla-ansible pull
    kolla-ansible prechecks
    kolla-ansible deploy
    kolla-ansible post-deploy
}

function openstack_initialize {
    source /etc/kolla/admin-openrc.sh
    /home/vagrant/sync/initialize.sh
}

initialize

configure_docker
configure_kolla

openstack_deploy
openstack_initialize

