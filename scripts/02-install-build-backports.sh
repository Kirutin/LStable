#!/usr/bin/env bash
set -euo pipefail

apply=0
[[ ${1:-} == --apply ]] && apply=1
packages=(wayland-protocols libwayland-dev libdrm-dev libxkbcommon-dev libpixman-1-dev)

if ! apt-cache policy "${packages[@]}" | grep 'pkg.noctalia.dev/deb trixie-backports' >/dev/null; then
  echo 'Die Noctalia-Trixie-Backports-Quelle ist nicht aktiv.' >&2
  echo 'Zuerst scripts/02-setup-noctalia-repo.sh ausfuehren.' >&2
  exit 1
fi

echo 'Benoetigte Buildbibliotheken aus Trixie-Backports:'
printf '  %s\n' "${packages[@]}"
echo
apt-get -s -t trixie-backports install --no-install-recommends "${packages[@]}" |
  sed -n '/The following additional packages will be installed:/,/^Conf /p'

if ((apply == 0)); then
  echo
  echo 'Trockenlauf. Nach ausdruecklicher Zustimmung erneut mit --apply starten.'
  exit 0
fi

as_root() {
  if ((EUID == 0)); then
    "$@"
  elif command -v pkexec >/dev/null 2>&1 && [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]]; then
    pkexec "$@"
  else
    echo 'Polkit ist nicht verfuegbar.' >&2
    return 1
  fi
}

as_root apt-get -t trixie-backports install -y --no-install-recommends "${packages[@]}"

for requirement in \
  'wayland-protocols 1.47' \
  'wayland-server 1.24.0' \
  'libdrm 2.4.129' \
  'xkbcommon 1.8.0' \
  'pixman-1 0.46.0'
do
  read -r module minimum <<<"$requirement"
  pkg-config --atleast-version="$minimum" "$module" || {
    echo "$module erreicht $minimum nach der Installation nicht." >&2
    exit 1
  }
done
echo 'Buildbibliotheken erfuellen die Mindestversionen.'
