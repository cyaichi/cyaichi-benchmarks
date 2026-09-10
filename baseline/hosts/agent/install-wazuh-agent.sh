#!/bin/bash
# Install the pinned Wazuh agent. Enrollment happens at container start.
set -euo pipefail

WAZUH_VERSION="${WAZUH_VERSION:?}"
WAZUH_REVISION="${WAZUH_REVISION:?}"
PKG="${WAZUH_VERSION}-${WAZUH_REVISION}"

export DEBIAN_FRONTEND=noninteractive
export WAZUH_MANAGER="${WAZUH_MANAGER:-172.30.30.10}"
export WAZUH_AGENT_NAME="${WAZUH_AGENT_NAME:-dvwa-host}"

install -m 0755 /cyaichi/agent/policy-rc.d /usr/sbin/policy-rc.d

apt-get update
apt-get install -y --no-install-recommends \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  procps \
  python3

curl -fsSL --retry 5 --retry-delay 2 \
  https://packages.wazuh.com/key/GPG-KEY-WAZUH \
  | gpg --batch --quiet --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
  >/etc/apt/sources.list.d/wazuh.list

apt-get update
apt-get install -y --no-install-recommends "wazuh-agent=${PKG}"

python3 /cyaichi/agent/configure-ossec.py

install -d -m 0755 /opt/cyaichi/seed
cp -a /var/ossec/queue /opt/cyaichi/seed/ossec-queue
cp -a /var/ossec/logs /opt/cyaichi/seed/ossec-logs
cp -a /var/ossec/etc/client.keys /opt/cyaichi/seed/client.keys

sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/wazuh.list
apt-get update
rm -rf /var/lib/apt/lists/*
printf '%s\n' "$WAZUH_VERSION" >/cyaichi/wazuh-agent-version
echo "installed wazuh-agent ${PKG}"
