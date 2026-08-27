#!/usr/bin/env bash
set -euo pipefail

apply=0
[[ ${1:-} == --apply ]] && apply=1

source /etc/os-release
arch="$(dpkg --print-architecture)"
if [[ ${ID:-} != debian || ${VERSION_CODENAME:-} != trixie ]]; then
  echo "Dieses Repository-Skript ist nur fuer Debian Trixie gedacht." >&2
  exit 1
fi
if [[ $arch != amd64 && $arch != arm64 ]]; then
  echo "Noctalia stellt fuer Trixie nur amd64 und arm64 bereit (gefunden: $arch)." >&2
  exit 1
fi

keyring_url='https://pkg.noctalia.dev/deb/nickh-archive-keyring.deb'
source_url='https://pkg.noctalia.dev/deb/noctalia-trixie.sources'
source_target='/etc/apt/sources.list.d/noctalia-trixie.sources'

echo 'Geplante Aenderungen:'
echo "  1. Repository-Schluesselpaket laden: $keyring_url"
echo "  2. Trixie-Quelle installieren: $source_target"
echo '  3. APT-Paketlisten aktualisieren'
echo 'Es wird noch kein Noctalia-Paket installiert.'

if ((apply == 0)); then
  echo
  echo 'Trockenlauf. Nach ausdruecklicher Zustimmung erneut mit --apply starten.'
  exit 0
fi

command -v wget >/dev/null 2>&1 || {
  echo 'wget fehlt; zuerst die Abhaengigkeitsliste pruefen.' >&2
  exit 1
}

repo_tmp="$(mktemp -d)"
trap 'rm -rf "$repo_tmp"' EXIT
wget -q -O "$repo_tmp/nickh-archive-keyring.deb" "$keyring_url"
wget -q -O "$repo_tmp/noctalia-trixie.sources" "$source_url"

package="$(dpkg-deb -f "$repo_tmp/nickh-archive-keyring.deb" Package)"
[[ $package == nickh-archive-keyring ]] || {
  echo "Unerwartetes Schluesselpaket: $package" >&2
  exit 1
}
suites="$(sed -n 's/^Suites:[[:space:]]*//p' "$repo_tmp/noctalia-trixie.sources")"
architectures="$(sed -n 's/^Architectures:[[:space:]]*//p' "$repo_tmp/noctalia-trixie.sources")"
[[ " $suites " == *" trixie/ "* ]] || {
  echo 'Die geladene APT-Quelle ist nicht fuer Trixie.' >&2
  exit 1
}
[[ " $architectures " == *" $arch "* ]] || {
  echo "Die geladene APT-Quelle bietet $arch nicht an." >&2
  exit 1
}
grep -q '^URIs: https://pkg.noctalia.dev/deb/$' "$repo_tmp/noctalia-trixie.sources"

as_root() {
  if ((EUID == 0)); then
    "$@"
  elif command -v pkexec >/dev/null 2>&1 && [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]]; then
    pkexec "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo 'Weder Polkit noch sudo ist fuer privilegierte Schritte verfuegbar.' >&2
    return 1
  fi
}

as_root dpkg -i "$repo_tmp/nickh-archive-keyring.deb"
as_root install -m 0644 "$repo_tmp/noctalia-trixie.sources" "$source_target"
as_root apt-get update
apt-cache show noctalia >/dev/null 2>&1 || {
  echo 'Das Paket noctalia wurde nach dem Update nicht gefunden.' >&2
  exit 1
}
echo 'Noctalia-Repository fuer Debian Trixie ist eingerichtet.'
