#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
apply=0
[[ ${1:-} == --apply ]] && apply=1

# shellcheck disable=SC1091
source /etc/os-release
arch="$(dpkg --print-architecture)"
if [[ ${ID:-} != debian || ${VERSION_CODENAME:-} != trixie ]]; then
  echo 'Dieses Repository-Skript ist nur fuer Debian Trixie gedacht.' >&2
  exit 1
fi
if [[ $arch != amd64 && $arch != arm64 ]]; then
  echo "Yazi stellt fuer Debian nur amd64 und arm64 bereit (gefunden: $arch)." >&2
  exit 1
fi

keyring_url='https://yazi-rs.github.io/builds/yazi-keyring.gpg'
keyring_target='/usr/share/keyrings/yazi-keyring.gpg'
source_file="$ROOT_DIR/sources/packaging/apt/yazi.list"
source_target='/etc/apt/sources.list.d/yazi.list'

echo 'Geplante Aenderungen:'
echo "  1. Offiziellen Yazi-Schluessel laden: $keyring_url"
echo "  2. Stable-Quelle installieren: $source_target"
echo '  3. APT-Paketlisten aktualisieren'
echo 'Es wird noch kein Yazi-Paket installiert.'

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
wget -q -O "$repo_tmp/yazi-keyring.gpg" "$keyring_url"
file "$repo_tmp/yazi-keyring.gpg" | grep -q 'OpenPGP Public Key'

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

as_root install -m 0644 "$repo_tmp/yazi-keyring.gpg" "$keyring_target"
as_root install -m 0644 "$source_file" "$source_target"
as_root apt-get update
apt-cache show yazi >/dev/null 2>&1 || {
  echo 'Das Paket yazi wurde nach dem Update nicht gefunden.' >&2
  exit 1
}
echo 'Offizielles Yazi-Stable-Repository ist eingerichtet.'
