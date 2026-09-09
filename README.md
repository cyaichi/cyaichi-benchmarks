# Cyaichi Benchmarks

Public tests and benchmarks for [Cyaichi](https://github.com/cyaichi/cyaichi) harness development.

Cyaichi builds AI agent harnesses that stand up and run a cybersecurity defense program. This repo is where we test those harnesses, measure them, and publish the results so others can repeat the work.

This project is public on purpose. Do not put secrets, customer data, live case files, or private telemetry here.

The Cyaichi program itself lives in a separate private repo. This repo does not replace that program. It measures it.

## Architecture

The range is three isolated tenant networks (asset, attacker, SOC). Inbound
is allowed only from the test environment (`net-test`). Outbound goes through
a controlled proxy. The orchestrator and observer are host processes, not
lab containers.

Infrastructure is layered:

- **Baseline** — networks, ACLs, core services, Linux SIEM host, Linux attacker host
- **Scenario** — the test definition (scenario1 = baseline plus a DVWA host)
- **Session** — one run of that scenario with one Cyaichi config; kept on disk after stop

```sh
python3 scripts/cyaichi_session.py create scenario1 --config configs/example.yaml
python3 scripts/cyaichi_session.py stop <session-id>
python3 scripts/cyaichi_session.py resume <session-id>
```

- [docs/architecture.md](docs/architecture.md)
- [docs/sessions.md](docs/sessions.md)
