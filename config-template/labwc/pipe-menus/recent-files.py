#!/usr/bin/env python3
import html
import json
import shlex
from pathlib import Path

recent = Path.home() / ".local/state/noctalia/recently_used.json"
print("<openbox_pipe_menu>")
try:
    data = json.loads(recent.read_text(encoding="utf-8"))
except Exception:
    data = []

count = 0
if isinstance(data, list):
    candidates = data
elif isinstance(data, dict):
    candidates = data.get("items", []) or data.get("files", [])
else:
    candidates = []

for item in candidates:
    path = item.get("path") if isinstance(item, dict) else str(item)
    if not path:
        continue
    label = Path(path).name or path
    command = "xdg-open " + shlex.quote(path)
    print(f'  <item label="{html.escape(label, quote=True)}" icon="document-open-recent">')
    print(f'    <action name="Execute" command="{html.escape(command, quote=True)}" />')
    print("  </item>")
    count += 1
    if count >= 15:
        break

if count == 0:
    print('  <item label="Keine zuletzt verwendeten Dateien" icon="dialog-information" />')
print("</openbox_pipe_menu>")
