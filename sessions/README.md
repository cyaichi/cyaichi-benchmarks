# Sessions

Created by `python3 scripts/cyaichi_session.py create`. Each subdirectory is
one run of a scenario with one Cyaichi config: its own Compose project, bind
mounts, config copy, and results.

Sessions are not deleted by `stop`. Resume with `resume` on the same id.

See [docs/sessions.md](../docs/sessions.md).
