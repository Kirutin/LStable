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

case "$scope" in
  build) packages=("${BUILD_PACKAGES[@]}") ;;
  runtime) packages=("${RUNTIME_PACKAGES[@]}") ;;
  all) packages=("${BUILD_PACKAGES[@]}" "${RUNTIME_PACKAGES[@]}") ;;
  *) echo "Aufruf: $0 [--apply] [build|runtime|all]" >&2; exit 2 ;;
esac

available=()
unavailable=()
for package in "${packages[@]}"; do
  if apt-cache show "$package" >/dev/null 2>&1; then
    available+=("$package")
  else
    unavailable+=("$package")
  fi
done

printf 'Vorgesehene Pakete (%s):\n' "$scope"
printf '  %s\n' "${available[*]}"
if ((${#unavailable[@]})); then
  printf '\nIn den aktuellen Paketquellen nicht gefunden:\n  %s\n' "${unavailable[*]}"
  printf 'Codex muss diese Namen auf dem Zielsystem klaeren; sie werden nicht stillschweigend ersetzt.\n'
fi

if ((apply == 0)); then
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

as_root apt-get update
as_root apt-get install -y --no-install-recommends "${available[@]}"

printf '\nAbhaengigkeiten installiert. Ghostty wird absichtlich separat behandelt.\n'
