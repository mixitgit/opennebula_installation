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


read -p "INSTALLATION_SCRIPT: Welcome to OpenNebula frontend installation
Be sure the script is being executed as root! [ENTER]" q

echo "INSTALLATION_SCRIPT: Choose the installation part:
1 - SELINUX disabling and installing utilities
2 - opennebula installation
3 - ssh configuration "

read -p "installation part ": part

#3 - MySQL setup
#4 - finishing frontend installation

if [[ ${part} == 1 ]]
then
  read -p "INSTALLATION_SCRIPT: Step 1. Disabling SELINUX and installing utils [ENTER] " q

  test "yum install -y net-tools vim wget"
  test "hostnamectl set-hostname frontend.localdomain"
  test "sed -i 's/SELINUX=[a-z][a-z]*/SELINUX=disabled/g' /etc/selinux/config"

  read -p "INSTALLATION_SCRIPT: Now reboot the machine [ENTER]" q
  reboot
fi
# reboot

if [[ ${part} == 2 ]]
then

  read -p "INSTALLATION_SCRIPT: installing OpenNebula components [ENTER] " q

  test "cat << EOT > /etc/yum.repos.d/opennebula.repo
[opennebula]
name=opennebula
baseurl=https://downloads.opennebula.org/repo/5.8/CentOS/7/x86_64
enabled=1
gpgkey=https://downloads.opennebula.org/repo/repo.key
gpgcheck=1
#repo_gpgcheck=1
EOT"

  test "yum install -y epel-release"
  test "yum install -y opennebula-server opennebula-sunstone opennebula-ruby opennebula-gate opennebula-flow"
  test "/usr/share/one/install_gems"
#fi
#if [[ ${part} == 3 ]]
#then

  read -p "INSTALLTION_SCRIPT: installing and configuring MySQL for OpenNebula [ENTER] " q

  test "yum -y update && yum -y upgrade"
  test "wget http://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm"
  test "rpm -Uvh mysql80-community-release-el7-3.noarch.rpm"
  test "yum install -y mysql-server"

  test "systemctl enable mysqld"
  test "systemctl start mysqld"
  test "systemctl status mysqld"

  default_pass=$(grep 'temporary password' /var/log/mysqld.log | tail -1 | sed 's/.*: //g')

  echo "INSTALLATION_SCRIPT: changing validate policy to LOW"
  test "echo 'validate_password.policy=LOW' >> /etc/my.cnf" ######### МОЖЕТ БЫТЬ ПРИЧИНОЙ ОШИБКИ!!! КАВЫЧКИ ИЗМЕНЕНЫ

  test "systemctl restart mysqld"

  echo "INSTALLATION_SCRIPT: changing MySQL root password"

  read -p "INSTALLATION_SCRIPT: Enter password for root: " root_password
  mysql --connect-expired-password -u root -p${default_pass} <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${root_password}';
EOF

  while [[ $? -ne 0 ]]
  do

    read -p "INSTALLATION_SCRIPT: ERROR changing MySQL root_password. Retry? [y/n]" q

    if [[ $q == 'y' ]]
    then
      read -p "INSTALLATION_SCRIPT: Enter password for root: " root_password
      mysql --connect-expired-password -u root -p${default_pass} <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${root_password}';
EOF

    elif [[ $q == 'n' ]]
    then
      break

    fi

  done

  test "systemctl restart mysqld"

  read -p "INSTALLATION_SCRIPT: run mysql_secure_installation? [y/n] " q
  if [[ $q == 'y' ]]
  then
    #read -p  "INSTALLTION_SCRIPT: Use this password during installation ---> $default_pass <---[ENTER] " q
    mysql_secure_installation
    systemctl restart mysqld
  fi

  echo "INSTALLATION_SCRIPT: setting up oneadmin"

  echo "oneadmin:$oneadmin_password" > /var/lib/one/.one/one_auth

  test  "mysql -u root -p$root_password <<EOF
CREATE USER 'oneadmin'@'localhost' IDENTIFIED BY '${oneadmin_password}';
GRANT ALL PRIVILEGES ON opennebula.* TO 'oneadmin'@'localhost' WITH GRANT OPTION;
SET GLOBAL TRANSACTION ISOLATION LEVEL READ COMMITTED;
EOF"

  cat << EOT >> /etc/one/oned.conf
# Sample configuration for MySQL
DB = [ backend = "mysql",
       server  = "localhost",
       port    = 0,
       user    = "oneadmin",
       passwd  = "${oneadmin_password}",
       db_name = "opennebula" ]
EOT

    #mysql -u root -p$default_pass -e "validate_password_policy=LOW;"
    #grep 'temporary password' /var/log/mysqld.log | sed 's/.*: //g' | xclip -selection clipboard
    #read -p "INSTALLATION_SCRIPT: DELETING validate policy plugin [I UNDERSTAND]" q
    #temp_pass=Sukakakzheyazaebalsarabotaipozhalustagovnoebanoe!!!!!
    #mysql --connect-expired-password -u root -p$default_pass <<EOF
    #ALTER USER 'root'@'localhost' IDENTIFIED BY '$temp_pass';
    #UNINSTALL PLUGIN validate.password;
    #EOF
#fi
#if [[ ${part} == 4 ]]
#then
    read -p "INSTALLATION_SCRIPT: finishing frontend installation [ENTER] " q

    read -p "INSTALLATION_SCRIPT: Do you want to PERMANENTLY DISABLE firewalld? [y/n]" q

    if [[ $q == 'y' ]]
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

    echo "INSTALLATION_SCRIPT: starting services"

    test "systemctl start opennebula"
    test "systemctl start opennebula-sunstone"
    test "oneuser show"

    read -p "INSTALLATION SCRIPT: try opening http://<frontend_address>:9869 [ENTER] " q

    #read -p "INSTALLATION_SCRIPT: specify oneadmin password: " oneadmin_password

    test "oneuser passwd 0 ${oneadmin_password}"
    echo "oneadmin:${oneadmin_password}" > /var/lib/one/.one/one_auth

    test "systemctl enable opennebula"
    test "systemctl enable opennebula-sunstone"
    test "systemctl restart opennebula"
    test "systemctl restart opennebula-sunstone"

    read -p "INSTALLATION SCRIPT: Now install VM-hosts and proceed top step 5 [ENTER] " q
fi

if [[ ${part} == 5 ]]
then
    read -p "INSTALLATION SCRIPT: Configuring SSH [ENTER] " q

    read -p "INSTALLATION SCRIPT: Fronend node ip: " frontend_ip
    read -p "INSTALLATION SCRIPT: VM Node IPs divided by ' ': " hosts_ip
    #sudo -u oneadmin /var/lib/one/.ssh/known_hosts

    test "sudo -u oneadmin ssh-keyscan ${frontend_ip} ${hosts_ip} | sudo -u oneadmin tee -a /var/lib/one/.ssh/known_hosts"

    read -p "INSTALLATION_SCRIPT: specify oneadmin password: " oneadmin_password
    echo -e "${oneadmin_password}\n${oneadmin_password}" | passwd oneadmin


    for host in ${hosts_ip}
    do
        test "sudo -u oneadmin scp -rp /var/lib/one/.ssh ${host}:/var/lib/one/ << EOF
yes
EOF"
        test "sudo -u oneadmin scp -rp frontend.localdomain:/var/lib/one/.ssh ${host}:/var/lib/one/ << EOF
yes
EOF"
        done

read -p "INSTALLATION_SCRIPT: OpenNebula installation is finished, rebooting the device"
reboot

fi