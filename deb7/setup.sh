#!/bin/bash
# debian 7 setup script
# inspired by lowendscript

function check_install {
  if [ -z "`which "$1" 2>/dev/null`" ]
  then
    executable=$1
    shift
    while [ -n "$1" ]
    do
      apt-get -q -y install "$1"
      print_info "$1 installed for $executable"
      shift
    done
  else
    print_warn "$2 already installed"
  fi
}

function check_remove {
  if [ -n "`which "$1" 2>/dev/null`" ]
  then
    apt-get -q -y remove --purge "$2"
    print_info "$2 removed"
  else
    print_warn "$2 is not installed"
  fi
}

function check_sanity {
  # Do some sanity checking.
  if [ $(/usr/bin/id -u) != "0" ]
  then
    die 'Must be run by root user'
  fi

  if [ ! -f /etc/debian_version ]
  then
    die "Distribution is not supported"
  fi
}

function die {
  echo "ERROR: $1" > /dev/null 1>&2
  exit 1
}

function get_password() {
  # Check whether our local salt is present.
  SALT=/var/lib/random_setup_salt
  if [ ! -f "$SALT" ]
  then
    head -c 512 /dev/urandom > "$SALT"
    chmod 400 "$SALT"
  fi
  password=`(cat "$SALT"; echo $1) | md5sum | base64`
  echo ${password:0:13}
}

function print_info {
  echo -n -e '\e[1;36m'
  echo -n $1
  echo -e '\e[0m'
}

function print_warn {
  echo -n -e '\e[1;33m'
  echo -n $1
  echo -e '\e[0m'
}

function install_dotdeb {
  cat > /etc/apt/sources.list.d/dotdeb.list <<END
  deb http://mirror.us.leaseweb.net/dotdeb/ stable all
  echo "deb-src http://mirror.us.leaseweb.net/dotdeb/ stable all
END

  wget -q -O - http://www.dotdeb.org/dotdeb.gpg | apt-key add -
}

function install_nano {
  check_install nano nano
}

function install_exim4 {
  # Need to stop sendmail as removing the package does not seem to stop it.
  if [ -f /usr/lib/sm.bin/smtpd ]
  then
    invoke-rc.d sendmail stop
    check_remove /usr/lib/sm.bin/smtpd 'sendmail*'
  fi

  check_install mail exim4
  if [ -f /etc/exim4/update-exim4.conf.conf ]
  then
    sed -i \
      "s/dc_eximconfig_configtype='local'/dc_eximconfig_configtype='internet'/" \
      /etc/exim4/update-exim4.conf.conf
    invoke-rc.d exim4 restart
  fi
}

function install_mysql {
  # Install the MySQL packages
  check_install mysqld mysql-server
  check_install mysql mysql-client

  # Install a low-end copy of the my.cnf to disable InnoDB
  invoke-rc.d mysql stop

  cat > /etc/mysql/conf.d/lowendbox.cnf <<END
[mysqld]
key_buffer = 8M
query_cache_size = 0

ignore_builtin_innodb
default_storage_engine=MyISAM
END

  invoke-rc.d mysql start

  # Generating a new password for the root user.
  passwd=`get_password root@mysql`
  mysqladmin password "$passwd"

  cat > ~/.my.cnf <<END
[client]
user = root
password = $passwd
END

  chmod 600 ~/.my.cnf
}

function install_mariadb {
  cat > /etc/apt/sources.list.d/MariaDB.list <<END
# MariaDB 5.5 repository list - created 2013-05-05 05:09 UTC
# http://mariadb.org/mariadb/repositories/
deb http://ftp.osuosl.org/pub/mariadb/repo/5.5/debian wheezy main
deb-src http://ftp.osuosl.org/pub/mariadb/repo/5.5/debian wheezy main
END

  apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
  apt-get -q -y update

  check_install mysql mariadb-server

  # Generating a new password for the root user.
  passwd=`get_password root@mysql`
  mysqladmin password "$passwd"

  cat > ~/.my.cnf <<END
[client]
user = root
password = $passwd
END

  chmod 600 ~/.my.cnf
}

function install_nginx {
  check_install nginx nginx
  invoke-rc.d nginx restart
}

function install_php {
  check_install php5 php5-common php5-cli php5-fpm php5-curl php5-gd php5-imap php5-mcrypt php5-mysql php-pear

  mkdir -p /var/run/php5-fpm
}

function remove_unneeded {
  # Some Debian have portmap installed. We don't need that.
  check_remove /sbin/portmap portmap

  # Other packages that seem to be pretty common in standard OpenVZ templates.
  check_remove /usr/sbin/apache2 'apache2*'
  check_remove /usr/sbin/named bind9
  check_remove /usr/sbin/smbd 'samba*'
  check_remove /usr/sbin/nscd nscd
}

function update_upgrade {
  # Run through the apt-get update/upgrade first. This should be done before
  # we try to install any package
  apt-get -q -y update
  apt-get -q -y upgrade
}

function update_timezone {
  dpkg-reconfigure tzdata
}

function update_sources {
  cat > /etc/apt/sources.list <<END
deb http://ftp.us.debian.org/debian wheezy main contrib non-free
deb http://security.debian.org/debian-security wheezy/updates main contrib non-free
END
}

function configure_ssh {
  echo "UseDNS no" >> /etc/ssh/sshd_config

  mkdir ~/.ssh && chmod 700 ~/.ssh
  touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys

  invoke-rc.d ssh restart
}

########################################################################
# START OF PROGRAM
########################################################################
export PATH=/bin:/usr/bin:/sbin:/usr/sbin

check_sanity
case "$1" in
exim4)
  install_exim4
  ;;
mysql)
  install_mysql
  ;;
mariadb)
  install_mariadb
  ;;
nginx)
  install_nginx
  ;;
php)
  install_php
  ;;
dotdeb)
  install_dotdeb
  update_upgrade
  ;;
system)
  update_timezone
  update_sources
  install_dotdeb
  remove_unneeded
  update_upgrade
  install_nano
  configure_ssh
  ;;
minimal)
  update_timezone
  update_sources
  install_dotdeb
  update_upgrade
  install_nano
  configure_ssh
  ;;
custom)
  print_warn "please update setup script to use this"
  ;;
*)
  echo 'Usage:' `basename $0` '[option]'
  echo 'Available options:'
  for option in minimal system custom dotdeb exim4 mysql mariadb nginx php; do
    echo '  -' $option
  done
  ;;
esac