#!/bin/sh

# List of databases to be backed up separated by space
dblist="db_name_1"

# Directory for backups
backupdir=/root/backups/mysql

# Number of days to keep
numdays=14

# Full path for MySQL hotcopy command
# Please put credentials into /root/.my.cnf
#hotcopycmd=/usr/bin/mysqlhotcopy
hotcopycmd="/usr/bin/mysqldump --lock-tables --databases"

# Backup date format
backupdate=`date +_%Y%m%d_%H%M`

# Create directory if needed
mkdir -p "$backupdir"
if [ ! -d "$backupdir" ]; then
  echo "Invalid directory: $backupdir"
  exit 1
fi

# Hotcopy begins here
echo "Dumping MySQL Databases..."
RC=0
for database in $dblist; do
  echo
  echo "Dumping $database..."
  $hotcopycmd $database | gzip > "$backupdir/$database$backupdate.sql.gz"
  
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
  find "$backupdir/" -type f -ctime "+$numdays" -exec rm -f {} \; -print
  
  echo
  echo "Listing Backup Directory Contents..."
  ls -la "$backupdir"
  
  echo
  echo "MySQL Dump is complete!"
fi

exit 0