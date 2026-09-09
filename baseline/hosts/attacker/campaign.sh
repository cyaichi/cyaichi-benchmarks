#!/bin/sh
# Reachability probe only. Scored attack stages live in the scenario pack
# and are invoked by the orchestrator; this file is a placeholder entrypoint.
set -e
target="${1:-http://dvwa-host.lab/}"
echo "campaign probe: GET ${target}"
curl -sS -o /dev/null -w "%{http_code} %{url_effective}\n" --max-time 10 "$target" || true
