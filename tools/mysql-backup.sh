#!/bin/sh
# MySQL Backup Script v1.1.1
# (c) 2013 Chris Talkington <chris@talkingontech.com>

# Space separated list of databases
dblist="db_name_1"

# Backup to this directory
backupdir=/root/backups/mysql

# Number of days to keep
numdays=14

# Put client credentials into $HOME/.my.cnf
dumpcmd="mysqldump --lock-tables --databases"
gzipcmd="gzip"

# Backup date format
backupdate=`date +_%Y%m%d_%H%M`

# Sanity checks
if [ ! -n "$dblist" ]; then
  echo "Invalid DB List"
  exit 1
fi

if [ ! -n "$backupdir" ]; then
  echo "Invalid Backup Dir"
  exit 1
fi

# Lock down permissions
umask 077

# Create directory if needed
mkdir -p -v $backupdir 
if [ ! -d $backupdir ]; then
  echo "Invalid directory: $backupdir"
  exit 1
fi

echo "Dumping MySQL Databases..."
RC=0

for database in $dblist; do
  echo
  echo "Dumping $database..."
  echo "$dumpcmd $database | $gzipcmd > $backupdir/$database$backupdate.sql.gz"
  $dumpcmd $database | $gzipcmd > "$backupdir/$database$backupdate.sql.gz"
    
  RC=$?
  if [ $RC -gt 0 ]; then
    continue;
  fi
done

echo

if [ $RC -gt 0 ]; then
  echo "MySQL Dump failed!"
  exit $RC
else
  findcmd="find $backupdir -name \"*.sql.gz\" -type f -mtime +$numdays -print0"
  findxargs="xargs -0 rm -fv"
  listcmd="ls -la $backupdir"
  
  echo "Removing Dumps Older Than $numdays Days..."
  echo "$findcmd | $findxargs"
  $findcmd | $findxargs
  
  echo
  echo "Listing Backup Directory Contents..."
  echo $listcmd
  $listcmd
  
  echo
  echo "MySQL Dump is complete!"
fi

exit 0