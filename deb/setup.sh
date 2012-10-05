#!/bin/bash
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
	SALT=/var/lib/radom_salt
	if [ ! -f "$SALT" ]
	then
		head -c 512 /dev/urandom > "$SALT"
		chmod 400 "$SALT"
	fi
	password=`(cat "$SALT"; echo $1) | md5sum | base64`
	echo ${password:0:13}
}

function install_dotdeb {
	echo "deb http://mirror.us.leaseweb.net/dotdeb/ stable all" >> /etc/apt/sources.list
	echo "deb-src http://mirror.us.leaseweb.net/dotdeb/ stable all" >> /etc/apt/sources.list
	wget -q -O - http://www.dotdeb.org/dotdeb.gpg | apt-key add -
}

function install_dash {
	check_install dash dash
	rm -f /bin/sh
	ln -s dash /bin/sh
}

function install_nano {
	check_install nano nano
}

function install_dropbear {
	check_install dropbear dropbear
	check_install /usr/sbin/xinetd xinetd
	
	# Disable SSH
	touch /etc/ssh/sshd_not_to_be_run
	invoke-rc.d ssh stop
	
	# Enable dropbear to start. We are going to use xinetd as it is just
	# easier to configure and might be used for other things.
	cat > /etc/xinetd.d/dropbear <<END
service ssh
{
    socket_type     = stream
    only_from       = 0.0.0.0
    wait            = no
    user            = root
    protocol        = tcp
    server          = /usr/sbin/dropbear
    server_args     = -i
    disable         = no
}
END
	invoke-rc.d xinetd restart
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

function install_nginx {
	check_install nginx nginx
	invoke-rc.d nginx restart
}

function install_php {
	check_install php5 php5-fpm php-pear php5-common php5-curl php5-imap php5-mcrypt php5-mysql php5-cli php5-gd
	
	mkdir -p /var/run/www
	chown www-data:www-data /var/run/www
}

function install_syslogd {
	# We just need a simple vanilla syslogd. Also there is no need to log to
	# so many files (waste of fd). Just dump them into
	# /var/log/(cron/mail/messages)
	check_install /usr/sbin/syslogd inetutils-syslogd
	invoke-rc.d inetutils-syslogd stop
	
	for file in /var/log/*.log /var/log/mail.* /var/log/debug /var/log/syslog
	do
		[ -f "$file" ] && rm -f "$file"
	done
	for dir in fsck news
	do
		[ -d "/var/log/$dir" ] && rm -rf "/var/log/$dir"
	done
	
	cat > /etc/syslog.conf <<END
*.*;mail.none;cron.none -/var/log/messages
cron.*                  -/var/log/cron
mail.*                  -/var/log/mail
END
	[ -d /etc/logrotate.d ] || mkdir -p /etc/logrotate.d
	cat > /etc/logrotate.d/inetutils-syslogd <<END
/var/log/cron
/var/log/mail
/var/log/messages {
   rotate 4
   weekly
   missingok
   notifempty
   compress
   sharedscripts
   postrotate
      /etc/init.d/inetutils-syslogd reload >/dev/null
   endscript
}
END
	invoke-rc.d inetutils-syslogd start
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

function remove_unneeded {
	# Some Debian have portmap installed. We don't need that.
	check_remove /sbin/portmap portmap
	
	# Remove rsyslogd, which allocates ~30MB privvmpages on an OpenVZ system,
	# which might make some low-end VPS inoperatable. We will do this even
	# before running apt-get update.
	check_remove /usr/sbin/rsyslogd rsyslog
	
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

function update_mirrors_us {
	echo "deb http://ftp.us.debian.org/debian squeeze main contrib non-free" > /etc/apt/sources.list
	echo "deb http://security.debian.org/debian-security squeeze/updates main contrib non-free" >> /etc/apt/sources.list
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
nginx)
	install_nginx
	;;
php)
	install_php
	;;
dotdeb)
	install_dotdeb
	;;
system)
	update_timezone
	update_mirrors_us
	remove_unneeded
	update_upgrade
	install_dash
	install_nano
	install_syslogd
	install_dropbear
	;;
minimal)
	update_timezone
	update_mirrors_us
	update_upgrade
	install_nano
	install_dotdeb
	;;
*)
	echo 'Usage:' `basename $0` '[option]'
	echo 'Available options:'
	for option in system dotdeb exim4 mysql nginx php
	do
		echo '  -' $option
	done
	;;
esac