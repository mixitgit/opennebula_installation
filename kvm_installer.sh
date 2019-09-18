#!/usr/bin/env bash

test() {

  eval "$1"
  log=$?

  while [[ $log -ne 0 ]]
  do
    read -p "INSTALLATION_SCRIPT: Command '''$1''' FAILED with code $log try again? [y/n]: " q

    if [[ $q == 'y' ]]
    then
      eval "$1"
      log=$?

    elif [[ $q == 'n' ]]
    then
      break

    fi

  done

  if [[ $log == 0 ]]
  then
    echo "INSTALLATION_SCRIPT: Command '''$1''' SUCCESS "

  fi

}


read -p "INSTALLATION_SCRIPT: Welcome to KVM node installation script
Be sure the script is being executed as root! [ENTER]" q


echo "INSTALLATION_SCRIPT: Installing utils"

test "yum install -y net-tools vim wget"
test "yum update -y"
test "yum upgrade -y"


echo "INSTALLATION_SCRIPT: Installing KVM OpenNebula"

test "cat << EOT > /etc/yum.repos.d/opennebula.repo
[opennebula]
name=opennebula
baseurl=https://downloads.opennebula.org/repo/5.8/CentOS/7/x86_64
enabled=1
gpgkey=https://downloads.opennebula.org/repo/repo.key
gpgcheck=1
#repo_gpgcheck=1
EOT"

test "yum install -y centos-release-qemu-ev"
test "yum install -y qemu-kvm-ev"
test "yum update -y"
test "yum upgrade -y"
test "yum install -y opennebula-node-kvm"
test "yum update -y"
test "yum upgrade -y"
test "systemctl restart libvirtd"

read -p "INSTALLATION_SCRIPT: Disabling SELINUX [ENTER] " q

test "sed -i 's/SELINUX=[a-z][a-z]*/SELINUX=disabled/g' /etc/selinux/config"

#cat /etc/selinux/config
#стало ненужно полсе введения теста

echo "INSTALLATION_SCRIPT: creating password for oneadmin"
read -p "INSTALLATION_SCRIPT: specify oneadmin password: " oneadmin_password
echo -e "${oneadmin_password}\n${oneadmin_password}" | passwd oneadmin

while [[ $? -ne 0 ]]
do
  read -p "INSTALLATION_SCRIPT: ERROR setting password, do you want to try again? [y/n] " q

  if [[ $q == 'y' ]]
  then
    read -p "INSTALLATION_SCRIPT: specify oneadmin password: " oneadmin_password
    echo -e "${oneadmin_password}\n${oneadmin_password}" | passwd oneadmin

  elif [[ $q == 'n' ]]
  then
    break
  fi
done


read -p "INSTALLATION_SCRIPT: Do you want to PERMANENTLY DISABLE firewalld? [y/n]" q

if [[ $q == y ]]
then
  test "systemctl stop firewalld"
  test "systemctl disable firewalld"

else
  echo "INSTALLATION_SCRIPT: adding port to firewall"
  test "firewall-cmd --permanent --add-port=9869/tcp"
  test "firewall-cmd --permanent --add-port=29876/tcp"
  test "firewall-cmd --reload"
  test "systemctl restart firewalld"
  test "firewall-cmd --list-ports"
fi

read -p "INSTALLATION_SCRIPT: Do you want to install a network bridge? [y/n]: " q

if [[ $q == y ]]
then
  read -p "INSTALLATION_SCRIPT: bridge interface name: " brname
  read -p "INSTALLATION_SCRIPT: bridge network IP: " brip
  read -p "INSTALLATION_SCRIPT: bridge network GATEWAY: " brgway
  read -p "INSTALLATION_SCRIPT: bridge network MASK: " brmask
  test "cat << EOT > /etc/sysconfig/network-scripts/ifcfg-$brname
STP=no
TYPE=Bridge
DEVICE=$brname
NAME='$brname'
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
EOT"

  read -p "INSTALLATION_SCRIPT: bridge slave device name: " slavename

  test "cat << EOT > /etc/sysconfig/network-scripts/ifcfg-$slavename
TYPE=Ethernet
NAME='$slavename-slave'
DEVICE=$slavename
ONBOOT=yes
BRIDGE=$brname
EOT"

fi

read -p "INSTALLATION_SCRIPT: KVM-host installation finished, rebooting the device"
reboot

#total interruptions = 3