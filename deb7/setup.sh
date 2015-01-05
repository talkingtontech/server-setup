#!/bin/bash
# debian 7 setup script v2.1
# inspired by lowendscript

SCRIPTNAME=$(basename $0)
COUNTRY="US"

function check_install {
  if [ -z "`which "$1" 2>/dev/null`" ]; then
    executable=$1
    shift
    while [ -n "$1" ]; do
      apt-get -q -y install "$1"
      print_info "$1 installed for $executable"
      shift
    done
  else
    print_warn "$2 already installed"
  fi
}

function check_remove {
  if [ -n "`which "$1" 2>/dev/null`" ]; then
    apt-get -q -y remove --purge "$2"
    print_info "$2 removed"
  else
    print_warn "$2 is not installed"
  fi
}

function check_sanity {
  # Do some sanity checking.
  if [ $(/usr/bin/id -u) != "0" ]; then
    die 'Must be run by root user'
  fi

  if [ ! -f /etc/debian_version ]; then
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

  if [ ! -f "$SALT" ]; then
    head -c 512 /dev/urandom > "$SALT"
    chmod 400 "$SALT"
  fi

  password=`(cat "$SALT"; echo $1) | md5sum | base64`
  echo ${password:0:13}
}

function set_country() {
  if [ "$@" == "US" ]; then
    COUNTRY="US"
  elif [ "$@" == "AU" ]; then
    COUNTRY="AU"
  else
    print_warn "unknown country; defaulting to US"
  fi

  print_info "country set to: $COUNTRY"
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
  LIST="/etc/apt/sources.list.d/dotdeb.list"

  echo "deb http://mirror.us.leaseweb.net/dotdeb/ stable all" > $LIST
  echo "deb-src http://mirror.us.leaseweb.net/dotdeb/ stable all" >> $LIST

  wget -q -O - http://www.dotdeb.org/dotdeb.gpg | apt-key add -
}

function install_nano {
  check_install nano nano
}

function install_mariadb {
  LIST="/etc/apt/sources.list.d/mariadb.list"
  PREF="/etc/apt/preferences.d/mariadb.pref"

  if [ "$COUNTRY" == "US" ]; then
    echo "deb http://ftp.osuosl.org/pub/mariadb/repo/5.5/debian wheezy main" > $LIST
    echo "deb-src http://ftp.osuosl.org/pub/mariadb/repo/5.5/debian wheezy main" >> $LIST
  elif [ "$COUNTRY" == "AU" ]; then
    echo "deb http://mirror.aarnet.edu.au/pub/MariaDB/repo/5.5/debian wheezy main" > $LIST
    echo "deb-src http://mirror.aarnet.edu.au/pub/MariaDB/repo/5.5/debian wheezy main" >> $LIST
  fi

  echo -e "Package: *\nPin: release o=MariaDB\nPin-Priority: 1005" > $PREF

  apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
  apt-get -q -y update

  check_install mysql mariadb-server mariadb-client mariadb-common libmariadbclient18
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
  LIST="/etc/apt/sources.list"
  SECLIST="/etc/apt/sources.list.d/security.list"
  SECPREF="/etc/apt/preferences.d/security.pref"
  STABLIST="/etc/apt/sources.list.d/stable.list"
  STABPREF="/etc/apt/preferences.d/stable.pref"

  echo "" > $LIST

  if [ "$COUNTRY" == "US" ]; then
    echo "deb http://ftp.us.debian.org/debian stable main contrib non-free" > $STABLIST
    echo "deb http://security.debian.org/debian-security stable/updates main contrib non-free" > $SECLIST
  elif [ "$COUNTRY" == "AU" ]; then
    echo "deb http://ftp.au.debian.org/debian stable main contrib non-free" > $STABLIST
    echo "deb http://security.debian.org/debian-security stable/updates main contrib non-free" > $SECLIST
  fi

  echo -e "Package: *\nPin: release a=stable\nPin-Priority: 995" > $STABPREF
  echo -e "Package: *\nPin: release l=Debian-Security\nPin-Priority: 1000" > $SECPREF
}

function configure_ssh {
  echo "UseDNS no" >> /etc/ssh/sshd_config

  mkdir -p ~/.ssh
  chmod 700 ~/.ssh

  touch ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys

  invoke-rc.d ssh restart
}

check_sanity

function usage() {
  cat << EOF
usage: $SCRIPTNAME cmd [-option]

This script automates the initial setup of a debian install.

COMMANDS:
  minimal    handles the basics of any new install
  system     minimal plus removal of un-needed packages
  dotdeb     sets up the dotdeb apt sources
  mysql      sets up mariadb apt sources and installs mariadb

OPTIONS:
  -h    Show this message
  -c    Set the country ie US/AU (defaults to US)
EOF
}

while getopts "hc:" opt; do
  case $opt in
    h)
      usage
      exit 1
      ;;
    c)
      set_country $OPTARG
      ;;
    \?)
      usage
      exit
      ;;
    :)
      die "Option -$OPTARG requires an argument."
      ;;
  esac
done

shift $(( ${OPTIND} - 1 ))

case "$1" in
  mysql)
    install_mariadb
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
    update_upgrade
    install_nano
    configure_ssh
    ;;
  *)
    usage
  ;;
esac