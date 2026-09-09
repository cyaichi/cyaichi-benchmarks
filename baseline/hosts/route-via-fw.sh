#!/bin/sh
# Point this host at the border firewall for other lab subnets.
# Usage: route-via-fw.sh <firewall-ip-on-this-l2>
set -e
fw="${1:?firewall ip required}"
if ! command -v ip >/dev/null 2>&1; then
  echo "route-via-fw: iproute2 not installed" >&2
  exit 1
fi
for net in 172.30.10.0/24 172.30.20.0/24 172.30.30.0/24 172.30.40.0/24 172.30.50.0/24; do
  if ip route show | grep -q "^${net} "; then
    continue
  fi
  ip route replace "$net" via "$fw" 2>/dev/null || ip route add "$net" via "$fw"
done
