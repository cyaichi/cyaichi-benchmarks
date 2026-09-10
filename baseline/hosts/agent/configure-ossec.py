#!/usr/bin/env python3
"""Point the Wazuh agent at soc-host and collect DVWA web telemetry."""

from __future__ import annotations

import os
import re
from pathlib import Path

CONF = Path("/var/ossec/etc/ossec.conf")
MANAGER = os.environ.get("WAZUH_MANAGER", "172.30.30.10")
AGENT_NAME = os.environ.get("WAZUH_AGENT_NAME", "dvwa-host")

text = CONF.read_text(encoding="utf-8")
text = text.replace("<address>MANAGER_IP</address>", f"<address>{MANAGER}</address>")
text = text.replace("<address>IP</address>", f"<address>{MANAGER}</address>")

if "<port>1514</port>" not in text:
    text = text.replace(
        f"<address>{MANAGER}</address>",
        f"<address>{MANAGER}</address>\n      <port>1514</port>\n      <protocol>tcp</protocol>",
        1,
    )

enrollment = f"""    <enrollment>
      <enabled>yes</enabled>
      <manager_address>{MANAGER}</manager_address>
      <port>1515</port>
      <agent_name>{AGENT_NAME}</agent_name>
    </enrollment>
"""
if "<enrollment>" not in text:
    text = text.replace("</client>", enrollment + "  </client>", 1)

if "/var/www/html" not in text:
    text = text.replace(
        "</syscheck>",
        "    <directories realtime=\"yes\" check_all=\"yes\">/var/www/html</directories>\n  </syscheck>",
        1,
    )

for path in ("/var/log/apache2/access.log", "/var/log/apache2/error.log"):
    if path in text:
        continue
    text = text.replace(
        "</ossec_config>",
        f"""
  <localfile>
    <log_format>apache</log_format>
    <location>{path}</location>
  </localfile>
</ossec_config>""",
        1,
    )

wodle = re.search(r'<wodle name="syscollector">.*?</wodle>', text, re.DOTALL)
if wodle and "<packages>" not in wodle.group(0):
    text = text.replace(
        wodle.group(0),
        wodle.group(0).replace(
            "</wodle>",
            "    <packages>yes</packages>\n    <ports all=\"no\">yes</ports>\n    <processes>yes</processes>\n  </wodle>",
            1,
        ),
        1,
    )

CONF.write_text(text, encoding="utf-8")
