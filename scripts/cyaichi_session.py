#!/usr/bin/env python3
"""Orchestrate Cyaichi test sessions (create, resume, stop).

A session is one run of a scenario with one Cyaichi config. stop does not
delete it; resume brings the same session back later.

This process is the orchestrator: it drives Compose and campaign lifecycle.
Scoring belongs to a separate observer process.
"""

from __future__ import annotations

import argparse
import json
import os
import secrets
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SESSIONS_ROOT = REPO_ROOT / "sessions"
DATA_DIRS = (
    "data/soc",
    "data/attacker",
    "data/firewall",
    "data/proxy/logs",
    "data/dns",
    "data/ntp",
    "data/dvwa",
    "results",
    "logs",
    "infra",
)


class SessionError(Exception):
    """User-facing failure."""


def utc_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def git_sha() -> str:
    try:
        out = subprocess.run(
            ["git", "-C", str(REPO_ROOT), "rev-parse", "--short", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        )
        return out.stdout.strip() or "unknown"
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def read_dotenv(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        values[key.strip()] = value.strip()
    return values


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def patch_metadata(session_dir: Path, **fields: str) -> None:
    path = session_dir / "metadata.json"
    data = read_json(path)
    data.update(fields)
    write_json(path, data)


def session_dir(session_id: str) -> Path:
    path = SESSIONS_ROOT / session_id
    if not path.is_dir() or not (path / "metadata.json").is_file():
        raise SessionError(f"unknown session: {session_id}")
    return path


def compose(session_path: Path, *args: str) -> None:
    env_file = session_path / ".env"
    values = read_dotenv(env_file)
    project = values.get("COMPOSE_PROJECT_NAME")
    scenario = values.get("SCENARIO")
    if not project or not scenario:
        raise SessionError(f"{env_file} is missing COMPOSE_PROJECT_NAME or SCENARIO")
    baseline = session_path / "infra" / "baseline" / "compose.yml"
    scenario_compose = session_path / "infra" / scenario / "compose.yml"
    if not baseline.is_file() or not scenario_compose.is_file():
        raise SessionError(f"session {session_path.name} is missing compose files")
    env = os.environ.copy()
    env.update(values)
    cmd = [
        "docker",
        "compose",
        "--project-directory",
        str(session_path),
        "--env-file",
        str(env_file),
        "-p",
        project,
        "-f",
        str(baseline),
        "-f",
        str(scenario_compose),
        *args,
    ]
    try:
        subprocess.run(cmd, check=True, env=env)
    except FileNotFoundError as exc:
        raise SessionError("docker is not installed or not on PATH") from exc
    except subprocess.CalledProcessError as exc:
        raise SessionError(f"docker compose {' '.join(args)} failed ({exc.returncode})") from exc


def merge_dns_hosts(session_path: Path, scenario: str) -> None:
    parts = [(session_path / "infra" / "baseline" / "dns" / "hosts").read_text(encoding="utf-8")]
    extra = session_path / "infra" / scenario / "dns" / "hosts"
    if extra.is_file():
        parts.append(extra.read_text(encoding="utf-8"))
    dest = session_path / "data" / "dns" / "hosts"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text("\n".join(p.rstrip() for p in parts) + "\n", encoding="utf-8")
    shutil.copyfile(
        session_path / "infra" / "baseline" / "dns" / "Corefile",
        session_path / "data" / "dns" / "Corefile",
    )
    shutil.copyfile(
        session_path / "infra" / "baseline" / "proxy" / "squid.conf",
        session_path / "data" / "proxy" / "squid.conf",
    )


def create_session(scenario: str, config: Path | None, session_id: str | None) -> Path:
    src = REPO_ROOT / "scenarios" / scenario
    if not src.is_dir():
        raise SessionError(f"no such scenario: {scenario} ({src})")
    if not (REPO_ROOT / "baseline" / "compose.yml").is_file():
        raise SessionError("baseline/compose.yml missing")
    if not (src / "compose.yml").is_file():
        raise SessionError(f"{scenario} has no compose.yml")

    stamp = utc_stamp()
    sid = session_id or f"{scenario}-{stamp}-{secrets.token_hex(3)}"
    path = SESSIONS_ROOT / sid
    if path.exists():
        raise SessionError(f"already exists: {path}")

    for rel in DATA_DIRS:
        (path / rel).mkdir(parents=True, exist_ok=True)
    (path / "data" / "proxy" / "logs").chmod(0o777)

    shutil.copytree(REPO_ROOT / "baseline", path / "infra" / "baseline")
    shutil.copytree(src, path / "infra" / scenario)
    merge_dns_hosts(path, scenario)

    config_src = config or (REPO_ROOT / "configs" / "example.yaml")
    if not config_src.is_file():
        raise SessionError(f"config not found: {config_src}")
    shutil.copyfile(config_src, path / "cyaichi.yaml")

    project = f"cyaichi-{sid}"
    (path / ".env").write_text(
        f"SESSION_DIR={path}\nSCENARIO={scenario}\nCOMPOSE_PROJECT_NAME={project}\n",
        encoding="utf-8",
    )
    write_json(
        path / "metadata.json",
        {
            "id": sid,
            "scenario": scenario,
            "created_at": stamp,
            "git_sha": git_sha(),
            "compose_project": project,
            "cyaichi_config": "cyaichi.yaml",
            "state": "created",
        },
    )
    return path


def cmd_create(args: argparse.Namespace) -> int:
    path = create_session(args.scenario, args.config, args.id)
    print(path.name)
    if args.no_start:
        return 0
    compose(path, "up", "-d", "--build")
    patch_metadata(path, state="up", last_up_at=utc_stamp())
    return 0


def cmd_resume(args: argparse.Namespace) -> int:
    path = session_dir(args.session_id)
    compose(path, "up", "-d", "--build")
    patch_metadata(path, state="up", last_up_at=utc_stamp())
    print(f"resumed {path.name}")
    return 0


def cmd_stop(args: argparse.Namespace) -> int:
    path = session_dir(args.session_id)
    compose(path, "down", "--remove-orphans")
    patch_metadata(path, state="down", last_down_at=utc_stamp())
    print(f"stopped {path.name} (session kept)")
    return 0


def cmd_list(_args: argparse.Namespace) -> int:
    if not SESSIONS_ROOT.is_dir():
        return 0
    for meta in sorted(SESSIONS_ROOT.glob("*/metadata.json")):
        data = read_json(meta)
        sid = data.get("id", meta.parent.name)
        state = data.get("state", "unknown")
        scenario = data.get("scenario", "")
        print(f"{sid}\t{state}\t{scenario}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="cyaichi_session.py",
        description="Create, resume, and stop Cyaichi test sessions. stop does not delete.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    create = sub.add_parser("create", help="create a new session and bring it up")
    create.add_argument("scenario", help="scenario name (e.g. scenario1)")
    create.add_argument(
        "--config",
        type=Path,
        help="Cyaichi config to copy into the session (default: configs/example.yaml)",
    )
    create.add_argument("--id", help="session id (default: scenario-timestamp-random)")
    create.add_argument(
        "--no-start",
        action="store_true",
        help="only create the session directory; do not start containers",
    )
    create.set_defaults(func=cmd_create)

    resume = sub.add_parser(
        "resume",
        aliases=["up"],
        help="start or resume an existing session",
    )
    resume.add_argument("session_id")
    resume.set_defaults(func=cmd_resume)

    stop = sub.add_parser(
        "stop",
        aliases=["down"],
        help="stop containers; keep the session on disk",
    )
    stop.add_argument("session_id")
    stop.set_defaults(func=cmd_stop)

    listing = sub.add_parser("list", help="list sessions on disk")
    listing.set_defaults(func=cmd_list)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except SessionError as exc:
        print(f"cyaichi_session: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
