#!/bin/sh
# Start Wazuh on soc-host. Packages live in the image; session state lives
# on bind mounts under the session data/soc directory.
set -eu

DATA=/var/lib/cyaichi
WAZUH_VERSION="$(cat /cyaichi/wazuh-version 2>/dev/null || echo unknown)"

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

seed_volumes() {
  mkdir -p "$DATA"
  seed_dir /var/lib/wazuh-indexer /opt/cyaichi/seed/indexer
  seed_dir /var/lib/filebeat /opt/cyaichi/seed/filebeat
  seed_dir /var/ossec/queue /opt/cyaichi/seed/ossec-queue
  seed_dir /var/ossec/logs /opt/cyaichi/seed/ossec-logs
  seed_dir /var/ossec/api/configuration /opt/cyaichi/seed/api-configuration
  seed_file /var/ossec/etc/client.keys /opt/cyaichi/seed/client.keys

  chown -R wazuh-indexer:wazuh-indexer /var/lib/wazuh-indexer || true
  chown wazuh:wazuh /var/ossec/etc/client.keys || true
}

indexer_up() {
  curl -sk --max-time 5 -u admin:admin https://127.0.0.1:9200/ >/dev/null 2>&1
}

init_security() {
  if [ -f "$DATA/.security-initialized" ]; then
    return 0
  fi
  sec="$(cat /cyaichi/security-config-path)"
  JAVA_HOME=/usr/share/wazuh-indexer/jdk \
  OPENSEARCH_JAVA_HOME=/usr/share/wazuh-indexer/jdk \
  OPENSEARCH_CONF_DIR=/etc/wazuh-indexer \
  bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh \
      -cd "$sec" -icl -p 9200 -nhnv \
      -cacert /etc/wazuh-indexer/certs/root-ca.pem \
      -cert /etc/wazuh-indexer/certs/admin.pem \
      -key /etc/wazuh-indexer/certs/admin-key.pem \
      -h 127.0.0.1
  touch "$DATA/.security-initialized"
}

wait_indexer() {
  i=0
  while [ "$i" -lt 90 ]; do
    if indexer_up; then
      return 0
    fi
    i=$((i + 1))
    sleep 2
  done
  echo "wazuh-indexer did not become ready" >&2
  return 1
}

if [ "${CYAICHI_SKIP_ROUTES:-}" != 1 ]; then
  /cyaichi/route-via-fw.sh 172.30.30.2
fi
seed_volumes

# Image config binds the indexer to loopback; harness search needs it on
# the container's published 9200 and on net-test.
sed -i 's/^network.host:.*/network.host: "0.0.0.0"/' /etc/wazuh-indexer/opensearch.yml

mm="$(cat /proc/sys/vm/max_map_count 2>/dev/null || echo 0)"
if [ "$mm" -lt 262144 ]; then
  echo "warning: vm.max_map_count=${mm}; set >= 262144 on the Docker host" >&2
fi

mkdir -p /tmp/wazuh-indexer /run/wazuh-indexer /var/log/wazuh-indexer /var/log/filebeat
chown wazuh-indexer:wazuh-indexer /tmp/wazuh-indexer /run/wazuh-indexer /var/log/wazuh-indexer

runuser -u wazuh-indexer -- env \
  OPENSEARCH_JAVA_HOME=/usr/share/wazuh-indexer/jdk \
  JAVA_HOME=/usr/share/wazuh-indexer/jdk \
  OPENSEARCH_HOME=/usr/share/wazuh-indexer \
  OPENSEARCH_PATH_CONF=/etc/wazuh-indexer \
  OPENSEARCH_TMPDIR=/tmp/wazuh-indexer \
  /usr/share/wazuh-indexer/bin/opensearch &
INDEXER_PID=$!

wait_indexer
init_security || true
wait_indexer

/var/ossec/bin/wazuh-control start

filebeat -e &
FILEBEAT_PID=$!

runuser -u wazuh-dashboard -- env \
  NODE_OPTIONS=--max-old-space-size=1024 \
  /usr/share/wazuh-dashboard/bin/opensearch-dashboards \
    --config /etc/wazuh-dashboard/opensearch_dashboards.yml &
DASHBOARD_PID=$!

echo "soc-host ready (Wazuh ${WAZUH_VERSION})"

while true; do
  if ! kill -0 "$INDEXER_PID" 2>/dev/null; then
    echo "wazuh-indexer exited" >&2
    exit 1
  fi
  if ! kill -0 "$FILEBEAT_PID" 2>/dev/null; then
    echo "filebeat exited" >&2
    exit 1
  fi
  if ! kill -0 "$DASHBOARD_PID" 2>/dev/null; then
    echo "wazuh-dashboard exited" >&2
    exit 1
  fi
  sleep 5
done
