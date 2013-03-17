#!/bin/sh

# List of databases to be backed up separated by space
dblist="db_name_1"

# Directory for backups
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
mkdir -p $backupdir 
if [ ! -d $backupdir ]; then
  echo "Invalid directory: $backupdir"
  exit 1
fi

# Hotcopy begins here
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
  echo "Removing Dumps Older Than $numdays Days..."
  echo "find $backupdir -name *.sql.gz -type f -mtime +$numdays -print0 | xargs -0 rm -fv"
  find $backupdir -name "*.sql.gz" -type f -mtime +$numdays -print0 | xargs -0 rm -fv
  
  echo
  echo "Listing Backup Directory Contents..."
  echo "ls -la $backupdir"
  ls -la $backupdir
  
  echo
  echo "MySQL Dump is complete!"
fi

exit 0