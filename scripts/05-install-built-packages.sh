#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
apply=0
[[ ${1:-} == --apply ]] && apply=1

[[ -d $ROOT_DIR/sources/build/lesbian-labwc-deb ]] || {
  echo 'Labwc-Buildordner fehlt. Zuerst Script 03 ausfuehren.' >&2
  exit 1
}

labwc="$(find "$ROOT_DIR/sources/build/lesbian-labwc-deb" -maxdepth 1 -type f -name 'lesbian-labwc_*_amd64.deb' -print | sort -V | tail -1)"
rmpc="$(find "$ROOT_DIR/sources/build/rmpc-deb" -maxdepth 1 -type f -name 'rmpc_*_amd64.deb' -print 2>/dev/null | sort -V | tail -1)"

[[ -n $labwc && -f $labwc ]] || { echo 'Labwc-Paket fehlt. Zuerst Script 03 ausfuehren.' >&2; exit 1; }
[[ -n $rmpc && -f $rmpc ]] || { echo 'rmpc-Paket fehlt. Zuerst Script 03 ausfuehren.' >&2; exit 1; }
if ! apt-cache show noctalia >/dev/null 2>&1; then
  echo 'Noctalia ist in den aktiven APT-Quellen nicht verfuegbar.' >&2
  echo 'Zuerst das Noctalia-Repository fuer Debian Trixie einrichten.' >&2
  exit 1
fi

echo 'Zu installierende Pakete:'
apt-cache show noctalia | sed -n '1,/^$/p' | grep -E '^(Package|Version|Architecture):'
dpkg-deb -f "$labwc" Package Version Architecture Depends
dpkg-deb -f "$rmpc" Package Version Architecture Depends

if ((apply == 0)); then
  apt-get -s --no-install-recommends install noctalia "$labwc" "$rmpc"
  echo
  echo 'Trockenlauf. Nach ausdruecklicher Zustimmung erneut mit --apply starten.'
  exit 0
fi

snapshot="$HOME/.local/state/warehouse-13-backups/packages-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$snapshot")"
dpkg-query -W -f='${Package}\t${Version}\n' > "$snapshot"

as_root() {
  if ((EUID == 0)); then
    "$@"
  elif command -v pkexec >/dev/null 2>&1 && [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]]; then
    pkexec "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo 'Weder Polkit noch sudo ist verfuegbar.' >&2
    return 1
  fi
}

as_root apt-get --no-install-recommends install -y noctalia "$labwc" "$rmpc"
echo "Paketstand vor Installation: $snapshot"
echo 'Jetzt Benutzerkonfiguration ausrollen und danach die neue Session starten.'
