#!/bin/sh
set -e
/cyaichi/route-via-fw.sh 172.30.10.2
if [ -x /usr/local/bin/docker-php-entrypoint ]; then
  exec /usr/local/bin/docker-php-entrypoint "$@"
fi
exec "$@"
