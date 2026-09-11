# Baseline range

Foundation shared by every scenario: networks, ACLs, core services, the
Linux SIEM/SOAR host, and the Kali Linux attacker host (`kali-linux-everything`).
No vulnerable asset lives here. scenario1 adds DVWA; scenario2 will add a
different host.

Software pins live in [versions.yaml](versions.yaml). soc-host currently
ships Wazuh 4.14.7. Scenario assets install the matching Wazuh agent from
`baseline/hosts/agent/`. A session freezes that file at create so later
upgrades stay out of old runs. Cyaichi agents authenticate to the Wazuh
manager API with a JWT (see `sessions/<id>/harness.yaml`); there is no
static API key.

Bring this up only as part of a **session** (`scripts/cyaichi_session.py`).
Do not `docker compose up` from this directory against a shared data path.
