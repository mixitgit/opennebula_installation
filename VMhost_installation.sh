#!/usr/bin/env bash

read -p "INSTALLATION_SCRIPT: Be sure the script is being executed as root! [ENTER]" q

cat << EOT > /etc/yum.repos.d/opennebula.repo
[opennebula]
name=opennebula
baseurl=https://downloads.opennebula.org/repo/5.8/CentOS/7/x86_64
enabled=1
gpgkey=https://downloads.opennebula.org/repo/repo.key
gpgcheck=1
#repo_gpgcheck=1
EOT

yum install -y net-tools vim wget
yum update -y
yum upgrade -y
yum install -y centos-release-qemu-ev
yum install -y qemu-kvm-ev
yum update -y
yum upgrade -y
yum install -y opennebula-node-kvm
yum update -y
yum upgrade -y
systemctl restart libvirtd

read -p "INSTALLATION_SCRIPT: Disabling SELINUX [ENTER] " q

sed -i 's/SELINUX=[a-z][a-z]*/SELINUX=disabled/g' /etc/selinux/config

cat /etc/selinux/config

read -p "INSTALLATION_SCRIPT: specify oneadmin password: " oneadmin_password
echo -e "${oneadmin_password}\n${oneadmin_password}" | passwd oneadmin

read -p "INSTALLATION_SCRIPT: Now reboot the machine and proceed to SSH configuration from frontend-node [ENTER] " q

read -p "INSTALLATION_SCRIPT: Do you want to PERMANENTLY DISABLE firewalld? [y/n]" q

if [[ $q == y ]]
    then
      systemctl stop firewalld
      systemctl disable firewalld

    else
      echo "INSTALLATION_SCRIPT: adding port to firewall"
firewall-cmd --permanent --add-port=9869/tcp
firewall-cmd --permanent --add-port=29876/tcp
firewall-cmd --reload
systemctl restart firewalld
firewall-cmd --list-ports

fi

read -p "INSTALLATION_SCRIPT: Do you want to install a network bridge? [y/n]: " q

if [[ $q == y ]]
then
  read -p "INSTALLATION_SCRIPT: bridge interface name: " brname
  read -p "INSTALLATION_SCRIPT: bridge network IP: " brip
  read -p "INSTALLATION_SCRIPT: bridge network GATEWAY: " brgway
  read -p "INSTALLATION_SCRIPT: bridge network MASK: " brmask
  cat << EOT > /etc/sysconfig/network-scripts/ifcfg-$brname
STP=no
TYPE=Bridge
DEVICE=$brname
NAME="$brname"
IPADDR=$brip
GATEWAY=$brgway
NETMASK=$brmask
BROADCAST=192.168.1.255
DNS1=8.8.8.8
DNS2=1.1.1.1
MTU=1500
ONBOOT=yes
BOOTPROTO=none
IPV6INIT=no
EOT

  read -p "INSTALLATION_SCRIPT: bridge slave device name: " slavename
  cat << EOT > /etc/sysconfig/network-scripts/ifcfg-$slavename
TYPE=Ethernet
NAME="$slavename-slave"
DEVICE=$slavename
ONBOOT=yes
BRIDGE=$brname
EOT

fi

reboot

#total interruptions = 3