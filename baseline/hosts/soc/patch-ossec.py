#!/usr/bin/env python3
"""Point the manager at localhost indexer and skip live vuln-feed downloads."""

from __future__ import annotations

import re
from pathlib import Path

CONF = Path("/var/ossec/etc/ossec.conf")
text = CONF.read_text(encoding="utf-8")

text = text.replace("https://0.0.0.0:9200", "https://127.0.0.1:9200")
text = text.replace("https://localhost:9200", "https://127.0.0.1:9200")


def disable_block(src: str, tag: str) -> str:
    pattern = re.compile(rf"(<{tag}\b.*?<enabled>)\s*yes\s*(</enabled>)", re.DOTALL | re.IGNORECASE)
    return pattern.sub(r"\1no\2", src, count=1)


text = disable_block(text, "vulnerability-detection")
text = disable_block(text, "vulnerability-detector")

# Offline lab: do not refresh the VD index even if a later overlay re-enables the wodle.
text = re.sub(
    r"(<index-status>)\s*yes\s*(</index-status>)",
    r"\1no\2",
    text,
    count=1,
    flags=re.IGNORECASE,
)

CONF.write_text(text, encoding="utf-8")
