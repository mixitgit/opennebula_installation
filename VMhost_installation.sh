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

reboot

#total interruptions = 3