# Baseline, scenarios, and sessions

A **baseline** is the foundation we keep stable. A **scenario** is the
specific test configuration (baseline plus one vulnerable-asset pack). A
**session** is one run of that scenario with one Cyaichi config, in its own
directory.

Sessions persist. `stop` stops containers; the directory stays so you can
`resume` the same session later. Sessions are not deleted by this CLI.

```
create  →  (running)  →  stop
                 ↑                         |
                 └──── later: resume ──────┘
```

A different Cyaichi config is a **new session**, not a restart of the old
one. Restarting a session brings back that session's disks (Wazuh state,
DVWA, logs). Comparing configs means comparing two `sessions/*/results/`
trees.

## Layers

| Layer | In git | Running? | What it is |
| --- | --- | --- | --- |
| **Baseline** | `baseline/` | No | Networks, ACLs, core services, `soc-host`, `attacker-host` |
| **Scenario** | `scenarios/scenario1/` | No | The test definition. scenario1 = baseline + DVWA |
| **Session** | `sessions/<id>/` (gitignored) | After `create`/`resume`, until `stop` | One run: frozen infra + `data/` + `cyaichi.yaml` + `results/` |

`scenario2` will be another directory next to `scenario1` that adds a
different host. It still includes the same baseline. Sessions of scenario1
and scenario2 never share mounts.

`net-test` is still the harness inbound network. That is not a session.

## Baseline

Creates the five networks, programs the border firewall, and starts core
services plus the two Linux hosts that every scenario reuses.

| Piece | Address | Role |
| --- | --- | --- |
| `net-asset` | 172.30.10.0/24 | Vulnerable hosts (empty until a scenario) |
| `net-attacker` | 172.30.20.0/24 | Adversary host |
| `net-soc` | 172.30.30.0/24 | SIEM/SOAR host |
| `net-test` | 172.30.40.0/24 | Only inbound source (harness) |
| `net-egress` | 172.30.50.0/24 | Proxy, DNS, NTP |
| `firewall` | *.2 on each net | Default-deny forward; east-west allowlist |
| `proxy` | *.3 on tenant nets + egress | HTTP(S) proxy, deny-all until a scenario allowlists |
| `dns` | *.4 on tenant nets + egress | Lab names; external recurse only from `net-egress` |
| `ntp` | 172.30.50.5 | Serves the host clock to tenants |
| `soc-host` | 172.30.30.10 | Linux host that runs Wazuh (SIEM/SOAR) |
| `attacker-host` | 172.30.20.10 | Linux host that runs the campaign |

Tenant networks are Compose `internal: true`. Hosts are single-homed. Only
`firewall`, `proxy`, and `dns` sit on more than one network.

`soc-host` is the SIEM/SOAR machine, not a cluster of published Wazuh
containers on the internet. Wazuh is installed **on that host**. Indexer
storage lives under the session's `data/soc/` so a second session cannot
see the first session's alerts.

## scenario1

Adds `dvwa-host` at 172.30.10.10 on `net-asset`, lab DNS name
`dvwa-host.lab`, and a Wazuh agent enrollment toward `soc-host` once the
manager is up. The scored campaign is scenario-specific and stays off the
harness mounts.

Default DVWA credentials are the upstream lab defaults. They are not
production secrets. Do not publish port 80 on the Docker host.

## Session directory

`scripts/cyaichi_session.py create` snapshots baseline + scenario into a new
directory so that session is a discrete unit (infra version + data +
config + results):

```
sessions/scenario1-20260909T210000Z-a1b2/
  .env                 # COMPOSE_PROJECT_NAME, SESSION_DIR, SCENARIO
  metadata.json
  cyaichi.yaml         # copy of the config under test
  infra/baseline/      # snapshot, not a live checkout
  infra/scenario1/
  data/                # bind mounts: soc, attacker, dvwa, proxy, …
  results/             # scores and traces; survive down
  logs/
```

`COMPOSE_PROJECT_NAME` is unique per directory, so Docker **containers and
networks** cannot collide across sessions. Images are a different object:
they are shared.

## Docker: shared images, per-session labs

The Docker engine on the host is the hypervisor for every session. Compose
does not give each session its own daemon.

| Docker object | Shared across sessions? | Why |
| --- | --- | --- |
| Images (and layer cache) | Yes | The bits that make `soc-host`, DVWA, firewall, CoreDNS |
| Containers | No | One running lab per session |
| Networks (`net-asset`, …) | No | Unique Compose project name |
| Bind mounts (`sessions/<id>/data`) | No | Wazuh/DVWA state must not leak between runs |

**Images are the catalog. Sessions are instantiations.**

Two kinds of images:

1. **Upstream** — pulled once, reused forever on that machine. Today that is
   `coredns/coredns:1.11.3` and bases such as `ubuntu:24.04` and
   `ghcr.io/digininja/dvwa`.
2. **Cyaichi** — images we build from `baseline/` and `scenarios/`
   (`firewall`, `proxy`, `ntp`, `soc-host`, `attacker-host`, `dvwa-host`).
   These should be named and versioned (`cyaichi/soc-host:<git-sha>`) so
   every session on the machine starts the same bits. Later those tags live
   in a registry (GHCR or similar) so CI and other hosts pull the same pins
   instead of rebuilding.

`stop` / `resume` throw away and recreate **containers**. They keep the
session directory and they reuse images. They do not snapshot a running
container as a new image.

What we should not share: a single Wazuh volume, a single DVWA disk, or a
single Compose project. Those are session state, not the image library.

Today `create`/`resume` pass `--build` and Compose names built images after
the project (`cyaichi-<session>-soc-host`). Layer cache is still shared, but
the tags are not yet a real catalog. The next slice is: build once into
`cyaichi/*:<sha>`, record the digest in `metadata.json`, and have sessions
only `docker compose up` those images (no rebuild on resume).

## CLI

From the repo root:

```sh
python3 scripts/cyaichi_session.py create scenario1 --config configs/example.yaml
python3 scripts/cyaichi_session.py stop <session-id>
python3 scripts/cyaichi_session.py resume <session-id>
python3 scripts/cyaichi_session.py list
```

| Command | Effect |
| --- | --- |
| `create <scenario>` | New session directory, copy infra and Cyaichi config, then start it. `--no-start` skips containers. |
| `resume <id>` | Start an existing session (same as after `stop`). |
| `stop <id>` | Stop containers and networks. **Keep** the directory, `data/`, and `results/`. |
| `list` | Sessions on disk, with state. |

`create`, `resume`, `stop`, and `list` never delete a session.

Two Cyaichi configs against scenario1 means two `create`s. Sequential on
one machine is expected: a full SIEM host is RAM-heavy.

The orchestrator is this CLI (`create` / `resume` / `stop`). The observer is
a separate host process that attaches to a session id, records health and
campaign outcomes, and writes `results/`. Neither is a container.

## What is not shared

- Docker Compose project name, containers, and networks
- Bind-mounted `data/` (Wazuh queues, DVWA state, proxy logs)

What **is** shared: the Docker engine and its image store (our catalog plus
upstream pulls). Git snapshots in `infra/` mean session A can keep an older
compose file while you edit `baseline/` for the next session. Image tags
should be pinned so that file still boots the bits it was created with.
