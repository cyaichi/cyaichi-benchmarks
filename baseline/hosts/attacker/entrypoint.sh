#!/bin/sh
set -e
/cyaichi/route-via-fw.sh 172.30.20.2
echo "attacker-host ready; campaign is scenario-provided"
exec sleep infinity
