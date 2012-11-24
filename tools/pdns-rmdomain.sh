#!/bin/bash

#######################################
# PowerDNS SQLite Domain Removal Tool #
# Version: 1.0.1                      #
#######################################

function confirm {
  echo -n "$@ "
  read answer
  for response in y Y yes YES Yes Sure sure SURE OK ok Ok
  do
    if [ "_$answer" == "_$response" ]; then
      return 0
    fi
  done

  # Any answer other than the list above is considerred a "no" answer
  return 1
}

echo "PowerDNS SQLite Domain Removal Tool (Domain and Records)";

domain=$1
domain_id=$(sqlite3 /var/lib/powerdns/pdns.sqlite3 "SELECT id FROM domains where name = '$domain'")

echo "Domain: $domain"
if [ -z "$domain_id" ]; then
  echo "Domain ID Not Found!"
else
  echo "Domain ID: $domain_id"
  echo ""

  confirm "Remove Domain?"
  if [ $? -eq 0 ]; then
    sqlite3 /var/lib/powerdns/pdns.sqlite3 "DELETE FROM domains where id = $domain_id"
    sqlite3 /var/lib/powerdns/pdns.sqlite3 "DELETE FROM records where domain_id = $domain_id"
  else
    echo "Removal Aborted!"
  fi
fi