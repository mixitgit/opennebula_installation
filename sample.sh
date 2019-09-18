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

#test commands

test "guigugiugig"

test "touch /home/mikes/test.txt"
#test "mv /home/mikes/test.txt /home/mikes/test2.txt"
#test "mv /home/mikes/test.txt /home/mikes/test2.txt"
test "mv /home/mikes/test2.txt /opt/"

test "cat << EOT > /home/mikes/test.txt
[opennebula]
name=opennebula
baseurl=https://downloads.opennebula.org/repo/5.8/CentOS/7/x86_64
enabled=1
gpgkey=https://downloads.opennebula.org/repo/repo.key
gpgcheck=1
#repo_gpgcheck=1
EOT"