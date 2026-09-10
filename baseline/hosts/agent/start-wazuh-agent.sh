#!/bin/bash
# Seed session-local agent state, wait for the manager, then start wazuh-agent.
set -eu

MANAGER="${WAZUH_MANAGER:-172.30.30.10}"
AUTH_PORT="${WAZUH_AUTH_PORT:-1515}"

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

seed_file() {
  dest=$1
  src=$2
  if [ -s "$dest" ]; then
    return 0
  fi
  if [ -f "$src" ]; then
    cp -a "$src" "$dest"
  else
    : >"$dest"
  fi
}

# DVWA's image sends Apache logs to stdout; Wazuh needs real files.
for f in /var/log/apache2/access.log /var/log/apache2/error.log; do
  if [ -L "$f" ] || [ ! -f "$f" ]; then
    rm -f "$f"
    touch "$f"
    chown www-data:www-data "$f" 2>/dev/null || true
  fi
done

if [ -d /opt/cyaichi/seed/ossec-queue ]; then
  seed_dir /var/ossec/queue /opt/cyaichi/seed/ossec-queue
  seed_dir /var/ossec/logs /opt/cyaichi/seed/ossec-logs
  seed_file /var/ossec/etc/client.keys /opt/cyaichi/seed/client.keys
  chown wazuh:wazuh /var/ossec/etc/client.keys 2>/dev/null || true
fi

wait_tcp() {
  host=$1
  port=$2
  i=0
  while [ "$i" -lt 60 ]; do
    if (echo >/dev/tcp/"$host"/"$port") >/dev/null 2>&1; then
      return 0
    fi
    i=$((i + 1))
    sleep 2
  done
  echo "wazuh-agent: timed out waiting for ${host}:${port}" >&2
  return 1
}

wait_tcp "$MANAGER" "$AUTH_PORT" || true
/var/ossec/bin/wazuh-control start
echo "wazuh-agent started (manager ${MANAGER})"
