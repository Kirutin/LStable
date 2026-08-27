#!/usr/bin/env python3
import configparser
import html
import os
import shlex
from pathlib import Path

CATEGORIES = [
    ("accessories", "Zubehör", "applications-accessories", {"Utility", "Core"}),
    ("development", "Entwicklung", "applications-development", {"Development"}),
    ("graphics", "Grafik", "applications-graphics", {"Graphics", "Photography"}),
    ("internet", "Internet", "applications-internet", {"Network", "WebBrowser", "Email"}),
    ("multimedia", "Multimedia", "applications-multimedia", {"Audio", "Video", "AudioVideo"}),
    ("office", "Büro", "applications-office", {"Office"}),
    ("system", "System", "applications-system", {"System", "Settings"}),
    ("utilities", "Werkzeuge", "applications-utilities", {"Utility"}),
]

SKIP_TERMS = ("kcm_", "mimeinfo", "org.kde.kded", "geoclue-demo", "hplj1020")

def clean_exec(value: str) -> str:
    parts = []
    for part in shlex.split(value, posix=True):
        if part.startswith("%"):
            continue
        parts.append(part)
    return " ".join(shlex.quote(part) for part in parts)

def read_desktop(path: Path):
    parser = configparser.RawConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    try:
        parser.read(path, encoding="utf-8")
    except Exception:
        return None
    if not parser.has_section("Desktop Entry"):
        return None
    sec = parser["Desktop Entry"]
    if sec.get("Type", "Application") != "Application":
        return None
    if sec.get("NoDisplay", "false").lower() == "true":
        return None
    if sec.get("Hidden", "false").lower() == "true":
        return None
    name = sec.get("Name[de_DE]") or sec.get("Name[de]") or sec.get("Name")
    command = sec.get("Exec")
    if not name or not command:
        return None
    if any(term in path.name for term in SKIP_TERMS):
        return None
    return {
        "name": name,
        "icon": sec.get("Icon", "application-x-executable"),
        "exec": clean_exec(command),
        "categories": {cat for cat in sec.get("Categories", "").split(";") if cat},
    }

def desktop_files():
    seen = set()
    dirs = [Path.home() / ".local/share/applications", Path("/usr/share/applications")]
    for directory in dirs:
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.desktop")):
            if path.name in seen:
                continue
            seen.add(path.name)
            item = read_desktop(path)
            if item:
                yield item

def esc(value):
    return html.escape(value or "", quote=True)

items = sorted(desktop_files(), key=lambda i: i["name"].casefold())
print("<openbox_pipe_menu>")
for menu_id, label, icon, wanted in CATEGORIES:
    bucket = [item for item in items if item["categories"] & wanted]
    if not bucket:
        continue
    print(f'  <menu id="apps-{esc(menu_id)}" label="{esc(label)}" icon="{esc(icon)}">')
    for item in bucket[:80]:
        print(f'    <item label="{esc(item["name"])}" icon="{esc(item["icon"])}">')
        print(f'      <action name="Execute" command="{esc(item["exec"])}" />')
        print("    </item>")
    print("  </menu>")
print("</openbox_pipe_menu>")
