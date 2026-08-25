#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/package-lists.sh"
# The legacy package list still contains build-only VM entries; the portable
# runtime set is the authoritative one for this installer.
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lesbian-stable-packages.sh"
RUNTIME_PACKAGES=("${LESBIAN_STABLE_RUNTIME_PACKAGES[@]}")

failures=0
warnings=0

ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARNUNG] %s\n' "$*"; warnings=$((warnings + 1)); }
fail() { printf '[FEHLER] %s\n' "$*"; failures=$((failures + 1)); }

printf 'Lesbian Stable Debian Preflight\n'
printf 'Projekt: %s\n\n' "$ROOT_DIR"

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  printf 'System: %s\n' "${PRETTY_NAME:-unbekannt}"
  if [[ ${ID:-} == debian ]]; then
    ok 'Debian erkannt'
  else
    fail "Dieses Paket ist fuer Debian gedacht, erkannt wurde ${ID:-unbekannt}"
  fi
  if [[ ${VERSION_CODENAME:-} == trixie ]]; then
    ok 'Debian 13 Trixie erkannt'
  else
    warn "Ziel wurde auf Trixie erstellt; ${VERSION_CODENAME:-unbekannt} braucht eine erneute Abhaengigkeits- und Patchpruefung"
  fi
else
  fail '/etc/os-release fehlt'
fi

arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
if [[ $arch == amd64 || $arch == x86_64 ]]; then
  ok "Architektur $arch"
else
  fail "Die Builder sind auf amd64 vorbereitet, erkannt wurde $arch"
fi

for cmd in bash git python3 sha256sum dpkg dpkg-deb apt-cache; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd vorhanden"
  else
    fail "$cmd fehlt"
  fi
done

printf '\nQuell-Bundles:\n'
for bundle in "$ROOT_DIR"/sources/vendor/*.bundle; do
  if git bundle list-heads "$bundle" >/dev/null 2>&1; then
    ok "$(basename "$bundle") lesbar"
  else
    fail "$(basename "$bundle") ist unlesbar"
  fi
done
noctalia_archive="$ROOT_DIR/sources/vendor/noctalia-v5.0.0-beta.8.tar.gz"
if [[ -f $noctalia_archive ]] && tar -tzf "$noctalia_archive" >/dev/null 2>&1; then
  ok 'noctalia-v5.0.0-beta.8.tar.gz lesbar'
else
  fail 'Noctalia-Quellarchiv fehlt oder ist unlesbar'
fi

if [[ -f "$ROOT_DIR/MANIFEST.sha256" ]]; then
  if (cd "$ROOT_DIR" && sha256sum -c MANIFEST.sha256 >/dev/null); then
    ok 'Archiv-Pruefsummen stimmen'
  else
    fail 'Mindestens eine Archiv-Pruefsumme stimmt nicht'
  fi
else
  warn 'MANIFEST.sha256 fehlt'
fi

printf '\nPaketmetadaten im aktuell konfigurierten APT:\n'
missing_build=()
missing_runtime=()
for package in "${BUILD_PACKAGES[@]}"; do
  apt-cache show "$package" >/dev/null 2>&1 || missing_build+=("$package")
done
for package in "${RUNTIME_PACKAGES[@]}"; do
  [[ $package == lesbian-labwc ]] && continue
  apt-cache show "$package" >/dev/null 2>&1 || missing_runtime+=("$package")
done

if ((${#missing_build[@]})); then
  warn "Nicht gefundene Build-Pakete: ${missing_build[*]}"
else
  ok 'Alle vorgesehenen Build-Paketnamen sind bekannt'
fi
if ((${#missing_runtime[@]})); then
  warn "Nicht gefundene Laufzeitpakete: ${missing_runtime[*]}"
else
  ok 'Alle vorgesehenen Laufzeit-Paketnamen sind bekannt'
fi

printf '\nBevorzugte Programme:\n'
for cmd in kitty bash firefox-esr firefox dolphin kate; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd vorhanden"
  else
    printf '[INFO] %s ist noch nicht installiert\n' "$cmd"
  fi
done
if ! command -v kitty >/dev/null 2>&1; then
  warn 'Kitty fehlt. Der portable Installer installiert Kitty als Terminalstandard.'
fi

printf '\nGrafik und Ausgaenge:\n'
command -v lspci >/dev/null 2>&1 && lspci -nnk | sed -n '/VGA compatible controller/,+3p;/3D controller/,+3p' || true
if command -v wlr-randr >/dev/null 2>&1 && [[ -n ${WAYLAND_DISPLAY:-} ]]; then
  wlr-randr || warn 'wlr-randr konnte den aktuellen Compositor nicht abfragen'
else
  printf '[INFO] Ausgabeerkennung spaeter in der laufenden Wayland-Session wiederholen.\n'
fi

printf '\nErgebnis: %d Fehler, %d Warnungen. Es wurden keine Aenderungen vorgenommen.\n' "$failures" "$warnings"
((failures == 0))
