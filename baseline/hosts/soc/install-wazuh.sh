#!/bin/bash
# Install pinned Wazuh central components into the soc-host image.
set -euo pipefail

WAZUH_VERSION="${WAZUH_VERSION:?}"
WAZUH_REVISION="${WAZUH_REVISION:?}"
FILEBEAT_VERSION="${FILEBEAT_VERSION:?}"
WAZUH_MAJOR="${WAZUH_VERSION%.*}"
PKG="${WAZUH_VERSION}-${WAZUH_REVISION}"

export DEBIAN_FRONTEND=noninteractive

install -m 0755 /cyaichi/policy-rc.d /usr/sbin/policy-rc.d

curl -fsSL --retry 5 --retry-delay 2 \
  https://packages.wazuh.com/key/GPG-KEY-WAZUH \
  | gpg --batch --quiet --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
  >/etc/apt/sources.list.d/wazuh.list

apt-get update
apt-get install -y --no-install-recommends \
  "wazuh-indexer=${PKG}" \
  "wazuh-manager=${PKG}" \
  "wazuh-dashboard=${PKG}" \
  "filebeat=${FILEBEAT_VERSION}"

install -d -m 0755 /tmp/wazuh-certs /opt/cyaichi
cp /cyaichi/certs.yml /tmp/wazuh-certs/config.yml
curl -fsSL --retry 5 --retry-delay 2 \
  -o /tmp/wazuh-certs/wazuh-certs-tool.sh \
  "https://packages.wazuh.com/${WAZUH_MAJOR}/wazuh-certs-tool.sh"
(
  cd /tmp/wazuh-certs
  bash ./wazuh-certs-tool.sh -A
  tar -C ./wazuh-certificates -cf ./wazuh-certificates.tar .
  tar -tf ./wazuh-certificates.tar
)

CERTS=/tmp/wazuh-certs/wazuh-certificates

install_certs() {
  local dest="$1" user="$2" group="$3"
  shift 3
  install -d -m 0500 "$dest"
  local name
  for name in "$@"; do
    cp -a "$CERTS/$name" "$dest/$name"
  done
  chmod 400 "$dest"/*
  chown -R "${user}:${group}" "$dest"
}

install_certs /etc/wazuh-indexer/certs wazuh-indexer wazuh-indexer \
  indexer.pem indexer-key.pem admin.pem admin-key.pem root-ca.pem

install_certs /etc/filebeat/certs root root \
  server.pem server-key.pem root-ca.pem
mv /etc/filebeat/certs/server.pem /etc/filebeat/certs/filebeat.pem
mv /etc/filebeat/certs/server-key.pem /etc/filebeat/certs/filebeat-key.pem
chmod 400 /etc/filebeat/certs/*
chown root:root /etc/filebeat/certs/*

install_certs /etc/wazuh-dashboard/certs wazuh-dashboard wazuh-dashboard \
  dashboard.pem dashboard-key.pem root-ca.pem

install -m 0644 /cyaichi/opensearch.yml /etc/wazuh-indexer/opensearch.yml
install -d -m 0755 /etc/wazuh-indexer/jvm.options.d
install -m 0644 /cyaichi/heap.options /etc/wazuh-indexer/jvm.options.d/heap.options
sed -i -E 's/^(-Xms|-Xmx)/#\1/' /etc/wazuh-indexer/jvm.options
chown wazuh-indexer:wazuh-indexer /etc/wazuh-indexer/opensearch.yml

install -m 0644 /cyaichi/filebeat.yml /etc/filebeat/filebeat.yml
curl -fsSL --retry 5 --retry-delay 2 \
  -o /etc/filebeat/wazuh-template.json \
  "https://raw.githubusercontent.com/wazuh/wazuh/v${WAZUH_VERSION}/extensions/elasticsearch/7.x/wazuh-template.json"
chmod go+r /etc/filebeat/wazuh-template.json
curl -fsSL --retry 5 --retry-delay 2 \
  "https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.5.tar.gz" \
  | tar -xz -C /usr/share/filebeat/module
filebeat keystore create
printf '%s' admin | filebeat keystore add username --stdin --force
printf '%s' admin | filebeat keystore add password --stdin --force

install -m 0644 /cyaichi/opensearch_dashboards.yml /etc/wazuh-dashboard/opensearch_dashboards.yml
install -d -m 0755 /usr/share/wazuh-dashboard/data/wazuh/config
install -m 0644 /cyaichi/wazuh.yml /usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml
chown -R wazuh-dashboard:wazuh-dashboard /usr/share/wazuh-dashboard/data /etc/wazuh-dashboard

python3 /cyaichi/patch-ossec.py
/var/ossec/bin/wazuh-keystore -f indexer -k username -v admin
/var/ossec/bin/wazuh-keystore -f indexer -k password -v admin

if [ -d /etc/wazuh-indexer/opensearch-security ]; then
  echo /etc/wazuh-indexer/opensearch-security >/cyaichi/security-config-path
elif [ -d /usr/share/wazuh-indexer/opensearch-security ]; then
  echo /usr/share/wazuh-indexer/opensearch-security >/cyaichi/security-config-path
else
  echo "wazuh security config directory not found" >&2
  exit 1
fi

cat >/opt/cyaichi/LAB-CREDENTIALS <<'EOF'
Lab defaults from the Wazuh step-by-step install. Not production secrets.
Do not publish soc-host ports on a public interface.

Dashboard: https://172.30.30.10/   admin / admin
Indexer:   https://127.0.0.1:9200  admin / admin
API:       https://172.30.30.10:55000  wazuh-wui / wazuh-wui
EOF

sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/wazuh.list
apt-get update
rm -rf /tmp/wazuh-certs /var/lib/apt/lists/*

printf '%s\n' "$WAZUH_VERSION" >/cyaichi/wazuh-version
echo "installed wazuh ${PKG} filebeat ${FILEBEAT_VERSION}"
