#!/bin/bash
# IPTables Country Block Script v1.2.6
# (c) 2013 Chris Talkington <chris@talkingontech.com>

# block all traffic from ISO code (eg ch for China)
ISO="af cn hk kr pe pk sg tw vn"

# provider (ipinfodb or ipdeny)
DLPROVIDER="ipinfodb"

# are we debugging
DEBUGME=false

# are we just testing
DRYRUNME=false

# set PATHs
IPTBIN=/sbin/iptables
WGETBIN=/usr/bin/wget
EGREPBIN=/bin/egrep
FINDBIN=/usr/bin/find

# save zones here
ZONEROOTDIR=/root/iptables/countryblock

# cache zones for this long
ZONECACHEMIN=1440

# init IP counter
IPCOUNT=0

# iptables chain used for rules
SPAMCHAIN="COUNTRYDROP"

# iptables chains to target
TARGETCHAINS="INPUT OUTPUT FORWARD"

# where to get rules from
DLROOTIPINFODB="http://ipinfodb.com/country_query.php"
DLROOTIPDENY="http://www.ipdeny.com/ipblocks/data/countries"

function ERROR() {
  echo && echo "[error] $@"
  exit 1
}

function NOTICE() {
  echo && echo "[notice] $@"
}

function DEBUG() {
  if $DEBUGME; then
    echo && echo $@
  fi
}

function RUNCMD() {
  DEBUG $@

  if ! $DRYRUNME; then
    $@
  fi
}

function FORCERUNCMD() {
  DEBUG $@
  $@
}

if $DRYRUNME; then
  NOTICE "Dryrun active. No iptables rules will be added."
fi

# lock down permissions
umask 077

# create directory if needed
mkdir -p -v $ZONEROOTDIR
if [ ! -d $ZONEROOTDIR ]; then
  ERROR "Invalid directory: $ZONEROOTDIR"
fi

# flush iptables chain
FLUSHCHAINCMD="$IPTBIN -F $SPAMCHAIN"
RUNCMD $FLUSHCHAINCMD

for tc in $TARGETCHAINS; do
  TARGETCMD="$IPTBIN -D $tc -j $SPAMCHAIN"
  RUNCMD $TARGETCMD
done

DELETECHAINCMD="$IPTBIN -X $SPAMCHAIN"
RUNCMD $DELETECHAINCMD

# create iptables chain
CREATECHAINCMD="$IPTBIN -N $SPAMCHAIN"
RUNCMD $CREATECHAINCMD

# build zones
for c in $ISO
do
  IPCOUNTISO=0

  tDB="$ZONEROOTDIR/$DLPROVIDER-$c.zone"

  if [ $DLPROVIDER == "ipdeny" ]; then
    DLZONECMD="$WGETBIN -O $tDB $DLROOTIPDENY/$c.zone"
  elif [ $DLPROVIDER == "ipinfodb" ]; then
    DLZONECMD="$WGETBIN -O $tDB $DLROOTIPINFODB?country=$c"
  else
    ERROR "Invalid List Provider: $DLPROVIDER"
  fi

  if [ -f $tDB ]; then
    CACHETESTCMD="$FINDBIN $tDB -cmin +$ZONECACHEMIN"
    DEBUG $CACHETESTCMD

    if test `$CACHETESTCMD`; then
      NOTICE "Updating $c zone cache"
      FORCERUNCMD $DLZONECMD
    fi
  else
    NOTICE "Creating $c zone cache"
    FORCERUNCMD $DLZONECMD
  fi

  if [ -f $tDB ]; then
    BADIPS=$($EGREPBIN -v "^#|^$" $tDB)

    for ipblock in $BADIPS; do
      DROPCMD="$IPTBIN -A $SPAMCHAIN -s $ipblock -j DROP"

      RUNCMD $DROPCMD

      IPCOUNTISO=$(($IPCOUNTISO + 1))
    done
  else
    NOTICE "Missing zone cache file: $tDB"
  fi

  IPCOUNT=$(($IPCOUNT + $IPCOUNTISO))

  NOTICE "Added $IPCOUNTISO $c IP blocks"
done

for tc in $TARGETCHAINS; do
  TARGETCMD="$IPTBIN -I $tc -j $SPAMCHAIN"
  RUNCMD $TARGETCMD
done

NOTICE "Finished; blocking a total of " $IPCOUNT " IP blocks"

exit 0