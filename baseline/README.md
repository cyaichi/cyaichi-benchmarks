# Baseline range

Foundation shared by every scenario: networks, ACLs, core services, the
Linux SIEM/SOAR host, and the Linux attacker host. No vulnerable asset lives
here. scenario1 adds DVWA; scenario2 will add a different host.

# Baseline range

Foundation shared by every scenario: networks, ACLs, core services, the
Linux SIEM/SOAR host, and the Linux attacker host. No vulnerable asset lives
here. scenario1 adds DVWA; scenario2 will add a different host.

Bring this up only as part of a **session** (`scripts/cyaichi_session.py`).
Do not `docker compose up` from this directory against a shared data path.
