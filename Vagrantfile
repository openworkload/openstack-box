# -*- mode: ruby -*-
# vi: set ft=ruby :

SETTINGS = {
  base_image: "bento/rockylinux-8.7",
  cpu: 4,
  memory: 32000,
  disk: '120GB'
}

Vagrant.configure(2) do |config|

  config.trigger.before [:up] do |trigger|
    if Vagrant.has_plugin?("vagrant-vbguest")
      puts 'Plugin vagrant-vbguest is already installed'
    else
      system('vagrant plugin install vagrant-vbguest')
    end
    if Vagrant.has_plugin?("vagrant-disksize")
      puts 'Plugin vagrant-disksize is already installed'
    else
      system('vagrant plugin install vagrant-disksize')
    end
  end

  config.disksize.size = SETTINGS[:disk]

  config.vbguest.installer_options = { allow_kernel_upgrade: true }
  config.vbguest.installer_hooks[:before_rebuild] = [
    "echo DNS1=8.8.8.8 >> /etc/sysconfig/network-scripts/ifcfg-eth0",
    "systemctl restart NetworkManager",
    "yum -y update kernel",
    "yum -y install kernel-headers kernel-devel gcc make perl elfutils-libelf-devel bzip2 tar",
    "yum -y remove policycoreutils-python-utils"  # https://www.virtualbox.org/ticket/19756
  ]

  config.vm.box = SETTINGS[:base_image]
  config.vm.network "private_network", ip: "172.28.128.2"

  # enable nested virtualization
  config.vm.provider "virtualbox" do |vb|
    vb.customize ['modifyvm', :id, '--nested-hw-virt', 'on']
  end

  config.vm.define "openstack.openworkload.org", primary: true do |admin|
    admin.vm.hostname = "openstack.openworkload.org"

    config.vm.provision "shell", run: "always", inline: <<-SHELL
    sudo xfs_growfs /dev/sda2
    SHELL
    admin.vm.provision :shell, path: "bootstrap.sh"
    admin.vm.synced_folder ".", "/home/vagrant/sync", disabled: false

    admin.vm.provider "virtualbox" do |vm|
      vm.cpus = SETTINGS[:cpu]
      vm.memory = SETTINGS[:memory]

      vm.customize ["modifyvm", :id, "--nictype1", "virtio"]
      vm.customize ["modifyvm", :id, "--cableconnected1", "on"]
      vm.customize ["modifyvm", :id, "--nictype2", "virtio"]
      vm.customize ["modifyvm", :id, "--cableconnected2", "on"]
      vm.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
      vm.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      vm.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    end
  end
end
