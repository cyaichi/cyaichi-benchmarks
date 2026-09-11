#!/bin/bash
# Install MariaDB on the DVWA asset so the web app has a local listener.
# The upstream ghcr.io/digininja/dvwa image is PHP/Apache only; official
# compose runs db as a second container. This range is one host.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

if [ -f /cyaichi/agent/policy-rc.d ]; then
  install -m 0755 /cyaichi/agent/policy-rc.d /usr/sbin/policy-rc.d
fi

apt-get update
apt-get install -y --no-install-recommends mariadb-server
rm -rf /var/lib/apt/lists/*

install -d -m 0755 /etc/mysql/mariadb.conf.d
cat >/etc/mysql/mariadb.conf.d/99-cyaichi.cnf <<'EOF'
[mysqld]
bind-address = 127.0.0.1
skip-networking = 0
EOF

if [ ! -d /var/lib/mysql/mysql ]; then
  mariadb-install-db --user=mysql --datadir=/var/lib/mysql
fi

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld /var/lib/mysql

mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=127.0.0.1 &
i=0
while [ "$i" -lt 30 ]; do
  if mariadb-admin ping --silent >/dev/null 2>&1; then
    break
  fi
  i=$((i + 1))
  sleep 1
done
if ! mariadb-admin ping --silent >/dev/null 2>&1; then
  echo "mariadb did not start during image build" >&2
  exit 1
fi

mariadb -u root <<'SQL'
CREATE DATABASE IF NOT EXISTS dvwa;
CREATE USER IF NOT EXISTS 'dvwa'@'127.0.0.1' IDENTIFIED BY 'p@ssw0rd';
CREATE USER IF NOT EXISTS 'dvwa'@'localhost' IDENTIFIED BY 'p@ssw0rd';
GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'127.0.0.1';
GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'localhost';
FLUSH PRIVILEGES;
SQL

mariadb-admin shutdown
i=0
while [ "$i" -lt 20 ]; do
  if ! mariadb-admin ping --silent >/dev/null 2>&1; then
    break
  fi
  i=$((i + 1))
  sleep 1
done

install -d -m 0755 /opt/cyaichi/seed
rm -rf /opt/cyaichi/seed/mysql
cp -a /var/lib/mysql /opt/cyaichi/seed/mysql
echo "installed mariadb for dvwa (127.0.0.1:3306)"
