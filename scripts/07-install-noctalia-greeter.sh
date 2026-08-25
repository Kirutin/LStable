#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
apply=0

if [[ ${1:-} == --apply ]]; then
  apply=1
elif (($#)); then
  echo "Aufruf: $0 [--apply]" >&2
  exit 2
fi

required_packages=(greetd noctalia-greeter accountsservice)
for package in "${required_packages[@]}"; do
  if [[ $(dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null || true) != ii* ]]; then
    echo "Fehlendes Paket: $package" >&2
    exit 1
  fi
done

for path in \
  "$ROOT_DIR/config-template/greetd/noctalia-greeter.toml" \
  "$ROOT_DIR/config-template/noctalia-greeter/greeter.toml" \
  "$ROOT_DIR/assets/warehouse-13-lesbian-greeter-wallpaper.png"
do
  [[ -f $path ]] || { echo "Fehlende Projektdatei: $path" >&2; exit 1; }
done

python3 - \
  "$ROOT_DIR/config-template/greetd/noctalia-greeter.toml" \
  "$ROOT_DIR/config-template/noctalia-greeter/greeter.toml" <<'PY'
import sys
import tomllib

for path in sys.argv[1:]:
    with open(path, "rb") as handle:
        tomllib.load(handle)
PY

echo 'Noctalia Greeter wird fuer den naechsten Systemstart eingerichtet.'
echo 'LightDM bleibt installiert und wird in der laufenden Sitzung nicht beendet.'
echo 'Zielsitzung: labwc-lesbian-stable'
echo 'Tastatur: de (nodeadkeys)'

if ((apply == 0)); then
  echo 'Trockenlauf. Erneut als root mit --apply starten.'
  exit 0
fi

if ((EUID != 0)); then
  echo 'Die Anwendung muss als root laufen.' >&2
  exit 1
fi

backup_stamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="/var/backups/warehouse-13-greeter/$backup_stamp"
install -d -m 0700 "$backup_dir"

for source in \
  /etc/greetd/config.toml \
  /etc/greetd/noctalia-greeter.toml \
  /var/lib/noctalia-greeter/greeter.toml \
  /var/lib/noctalia-greeter/sync.toml \
  /var/lib/noctalia-greeter/warehouse-13-lesbian-greeter-wallpaper.png
do
  if [[ -e $source || -L $source ]]; then
    install -d -m 0700 "$backup_dir$(dirname "$source")"
    cp -a "$source" "$backup_dir$source"
  fi
done
if [[ -L /etc/systemd/system/display-manager.service ]]; then
  readlink /etc/systemd/system/display-manager.service > "$backup_dir/display-manager.target"
fi

install -D -o root -g root -m 0644 \
  "$ROOT_DIR/config-template/greetd/noctalia-greeter.toml" \
  /etc/greetd/noctalia-greeter.toml
install -d -o _greetd -g _greetd -m 0750 /var/lib/noctalia-greeter
install -o _greetd -g _greetd -m 0640 \
  "$ROOT_DIR/config-template/noctalia-greeter/greeter.toml" \
  /var/lib/noctalia-greeter/greeter.toml
install -o _greetd -g _greetd -m 0640 \
  "$ROOT_DIR/assets/warehouse-13-lesbian-greeter-wallpaper.png" \
  /var/lib/noctalia-greeter/warehouse-13-lesbian-greeter-wallpaper.png

if systemctl list-unit-files lightdm.service >/dev/null 2>&1 &&
   systemctl list-unit-files lightdm.service | grep -q '^lightdm\.service'; then
  systemctl disable lightdm.service
else
  echo 'LightDM ist auf diesem Zielsystem nicht installiert; kein LightDM-Schritt nötig.'
fi
systemctl enable greetd.service

if [[ $(readlink -f /etc/systemd/system/display-manager.service) != /usr/lib/systemd/system/greetd.service ]]; then
  echo 'display-manager.service zeigt nicht auf greetd; Wechsel abgebrochen.' >&2
  exit 1
fi

echo "Sicherung: $backup_dir"
echo 'greetd ist fuer den naechsten Boot aktiviert; LightDM laeuft bis zum Abmelden weiter.'
