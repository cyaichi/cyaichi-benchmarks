#!/bin/sh
set -e
/cyaichi/route-via-fw.sh 172.30.30.2
echo "soc-host ready (Wazuh install is a follow-on; data dir is live)"
exec sleep infinity
