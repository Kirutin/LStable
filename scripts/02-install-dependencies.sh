#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/package-lists.sh"

apply=0
scope="${1:-all}"
if [[ $scope == --apply ]]; then
  apply=1
  scope="${2:-all}"
elif [[ ${2:-} == --apply ]]; then
  apply=1
fi

backport_build_packages=(
  wayland-protocols libwayland-dev libdrm-dev libxkbcommon-dev libpixman-1-dev
)
needs_build_backports=0

case "$scope" in
  build)
    packages=("${BUILD_PACKAGES[@]}")
    needs_build_backports=1
    ;;
  runtime)
    packages=("${RUNTIME_PACKAGES[@]}")
    ;;
  all)
    packages=("${BUILD_PACKAGES[@]}" "${RUNTIME_PACKAGES[@]}")
    needs_build_backports=1
    ;;
  *) echo "Aufruf: $0 [--apply] [build|runtime|all]" >&2; exit 2 ;;
esac

is_backport_build_package() {
  local candidate="$1" package
  for package in "${backport_build_packages[@]}"; do
    [[ $candidate == "$package" ]] && return 0
  done
  return 1
}

available=()
unavailable=()
for package in "${packages[@]}"; do
  if ((needs_build_backports)) && is_backport_build_package "$package"; then
    continue
  fi
  if apt-cache show "$package" >/dev/null 2>&1; then
    available+=("$package")
  else
    unavailable+=("$package")
  fi
done

printf 'Vorgesehene Pakete (%s):\n' "$scope"
printf '  %s\n' "${available[*]}"
if ((needs_build_backports)); then
  printf '\nSeparat aus Trixie-Backports:\n  %s\n' "${backport_build_packages[*]}"
fi
if ((${#unavailable[@]})); then
  printf '\nIn den aktuellen Paketquellen nicht gefunden:\n  %s\n' "${unavailable[*]}"
  printf 'Codex muss diese Namen auf dem Zielsystem klaeren; sie werden nicht stillschweigend ersetzt.\n'
fi

if ((apply == 0)); then
  if ((needs_build_backports)); then
    echo
    "$ROOT_DIR/scripts/02-install-build-backports.sh"
  fi
  printf '\nTrockenlauf. Nach ausdruecklicher Zustimmung erneut mit --apply starten.\n'
  exit 0
fi

if ((${#unavailable[@]})); then
  printf 'Abbruch: Erst die fehlenden Debian-Paketnamen klaeren.\n' >&2
  exit 1
fi

as_root() {
  if ((EUID == 0)); then
    "$@"
  elif command -v pkexec >/dev/null 2>&1 && [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]]; then
    pkexec "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo 'Weder Polkit noch sudo ist fuer den privilegierten Schritt verfuegbar.' >&2
    return 1
  fi
}

if ((needs_build_backports)); then
  "$ROOT_DIR/scripts/02-install-build-backports.sh" --apply
fi

as_root apt-get update
as_root apt-get install -y --no-install-recommends "${available[@]}"

printf '\nAbhaengigkeiten installiert. Ghostty wird absichtlich separat behandelt.\n'
