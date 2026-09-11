#!/bin/sh
set -e
/cyaichi/route-via-fw.sh 172.30.10.2
/cyaichi/start-mariadb.sh
/cyaichi/agent/start-wazuh-agent.sh
if [ -x /usr/local/bin/docker-php-entrypoint ]; then
  exec /usr/local/bin/docker-php-entrypoint "$@"
fi
exec "$@"
