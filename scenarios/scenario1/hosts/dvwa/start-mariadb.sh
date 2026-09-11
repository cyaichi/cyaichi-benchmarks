#!/bin/bash
# Seed session-local MariaDB data and start mysqld on loopback.
set -eu

seed_dir() {
  dest=$1
  src=$2
  mkdir -p "$dest"
  if [ -e "$dest/.cyaichi-seeded" ]; then
    return 0
  fi
  if [ -d "$src" ]; then
    cp -a "$src"/. "$dest"/
  fi
  touch "$dest/.cyaichi-seeded"
}

if [ -d /opt/cyaichi/seed/mysql ]; then
  seed_dir /var/lib/mysql /opt/cyaichi/seed/mysql
fi

mkdir -p /run/mysqld /var/lib/mysql /var/log/mysql
chown mysql:mysql /run/mysqld /var/log/mysql
chown -R mysql:mysql /var/lib/mysql

mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=127.0.0.1 >/var/log/mysql/error.log 2>&1 &

i=0
while [ "$i" -lt 30 ]; do
  if (echo >/dev/tcp/127.0.0.1/3306) >/dev/null 2>&1; then
    echo "mariadb listening on 127.0.0.1:3306"
    exit 0
  fi
  i=$((i + 1))
  sleep 1
done
echo "mariadb did not become ready on 127.0.0.1:3306" >&2
exit 1
