# scenario1

Baseline range plus a DVWA host on `net-asset` (172.30.10.10, `dvwa-host.lab`).

This pack does not include the networks or the SIEM/attacker hosts; those come
from `baseline/`. Create a session instead of composing this folder
alone:

```sh
python3 scripts/cyaichi_session.py create scenario1 --config configs/example.yaml
```

DVWA stays unpublished on the host. Default upstream lab credentials apply
inside the range only.
