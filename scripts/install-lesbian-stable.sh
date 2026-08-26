#!/usr/bin/env bash
set -euo pipefail

# Portable installer for the style-only Lesbian Stable profile.
# Default is a read-only plan. Root changes require --apply; rEFInd additionally
# requires --refind and is never touched as part of a normal desktop install.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lesbian-stable-packages.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/sources/SOURCE-PINS.env"

apply=0
build=0
refind=0

while (($#)); do
  case "$1" in
    --apply) apply=1; shift ;;
    --build) build=1; shift ;;
    --refind) refind=1; shift ;;
    -h|--help)
      cat <<'EOF'
Lesbian Stable Installer

  (ohne Optionen)  Plan/Dry-Run
  --apply           Pakete und Benutzerprofil wirklich installieren
  --build           Labwc 0.20.2 und rmpc aus den lokalen Bundles bauen
  --refind          rEFInd-Paket, Theme und Konfiguration einrichten

Beispiele:
  ./scripts/install-lesbian-stable.sh
  ./scripts/install-lesbian-stable.sh --apply --build
  ./scripts/install-lesbian-stable.sh --apply --refind

Der normale Desktop-Lauf fasst den EFI-Bootloader nicht an. --refind ist ein
separater, ausdrücklich aktivierter Schritt und braucht ein EFI-System mit
gemounteter ESP unter /boot/efi.
EOF
      exit 0
      ;;
    *) echo "Unbekannte Option: $1" >&2; exit 2 ;;
  esac
done

[[ $EUID -ne 0 ]] || {
  echo 'Bitte als normaler Benutzer starten; privilegierte Schritte fragen Polkit/sudo an.' >&2
  exit 1
}

# shellcheck disable=SC1091
source /etc/os-release
[[ ${ID:-} == debian ]] || {
  echo "Dieses Profil ist fuer Debian vorgesehen (gefunden: ${ID:-unbekannt})." >&2
  exit 1
}
if [[ ${VERSION_CODENAME:-} != trixie ]]; then
  echo "Warnung: getestet ist Debian Trixie; gefunden wurde ${VERSION_CODENAME:-unbekannt}."
fi
arch="$(dpkg --print-architecture)"
[[ $arch == amd64 ]] || {
  echo "Nicht unterstützte Architektur: $arch (dieser reproduzierbare Build ist für amd64 gepinnt)." >&2
  exit 1
}

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

local_labwc="$ROOT_DIR/sources/build/lesbian-labwc-deb/lesbian-labwc_"'*_amd64.deb'
local_rmpc="$ROOT_DIR/sources/build/rmpc-deb/rmpc_"'*_amd64.deb'
latest_match() {
  local pattern="$1"
  compgen -G "$pattern" | sort -V | tail -1 || true
}
labwc_deb="$(latest_match "$local_labwc")"
rmpc_deb="$(latest_match "$local_rmpc")"

echo 'Lesbian Stable – Installationsplan'
echo "  Debian: ${PRETTY_NAME:-${ID:-debian}}"
echo "  Architektur: $arch"
echo "  Labwc: $LABWC_REF (style-only, ohne HyFlair/CyLab/Tiling/Overview)"
echo '  Noctalia + Greeter: gezielt aus Trixie-Backports'
echo '  Noctalia Greeter: aktiviert die Session „labwc - lesbian singularity x7“'
echo '  Qt/GTK, Kitty, Firefox, Dolphin/Kate/Gwenview, Audio und Terminaltools'
if ((refind)); then
  echo '  rEFInd: ausdrücklich angefordert (EFI-Prüfungen folgen)'
else
  echo '  rEFInd: ausgelassen (Bootloader bleibt unverändert)'
fi

runtime_apt=()
for package in "${LESBIAN_STABLE_RUNTIME_PACKAGES[@]}"; do
  case "$package" in
    lesbian-labwc|noctalia|noctalia-greeter) ;;
    *) runtime_apt+=("$package") ;;
  esac
done

echo
echo 'Laufzeitpakete:'
printf '  %s\n' "${runtime_apt[@]}"
echo '  noctalia (Trixie-Backports)'
echo '  noctalia-greeter (Trixie-Backports)'
if ((build)); then
  echo
  echo 'Build: lokale Bundles + gepinnte Patches für Labwc und rmpc'
else
  echo
  echo 'Build: übersprungen; vorhandene lokale .deb-Dateien werden verwendet.'
  [[ -n $labwc_deb ]] && echo "  Labwc: $labwc_deb" || echo '  Labwc: FEHLT'
  [[ -n $rmpc_deb ]] && echo "  rmpc:  $rmpc_deb" || echo '  rmpc:  FEHLT'
fi

if ((refind)); then
  echo
  echo 'rEFInd-Schutzgrenzen:'
  echo '  - nur UEFI (/sys/firmware/efi)'
  echo '  - ESP muss unter /boot/efi gemountet sein'
  echo '  - bestehende rEFInd-Dateien werden vor dem Kopieren gesichert'
fi

if ((apply == 0)); then
  cat <<'EOF'

Trockenlauf. Es wurden keine Paketquellen, Pakete, Benutzerdateien oder Bootloader geändert.
Für die Desktop-Installation erneut mit --apply starten.
EOF
  exit 0
fi

if ((build == 0)); then
  [[ -n $labwc_deb && -f $labwc_deb ]] || {
    echo 'Labwc-.deb fehlt. Mit --build erneut starten.' >&2
    exit 1
  }
  [[ -n $rmpc_deb && -f $rmpc_deb ]] || {
    echo 'rmpc-.deb fehlt. Mit --build erneut starten.' >&2
    exit 1
  }
fi

echo
echo '[0/8] Bootstrap-Werkzeuge für signierte APT-Quellen bereitstellen'
as_root apt-get update
as_root apt-get install -y --no-install-recommends ca-certificates wget file

echo '[1/8] Noctalia-Quelle für Debian Trixie einrichten'
"$ROOT_DIR/scripts/02-setup-noctalia-repo.sh" --apply

echo '[2/8] Offizielle Yazi-Stable-Quelle einrichten'
"$ROOT_DIR/scripts/02-setup-yazi-repo.sh" --apply

echo '[3/8] Noctalia und Greeter aus Trixie-Backports installieren'
as_root apt-get update
for package in noctalia noctalia-greeter; do
  apt-cache show "$package" >/dev/null 2>&1 || {
    echo "Fehlendes Noctalia-Paket: $package" >&2
    exit 1
  }
done
as_root apt-get -t trixie-backports install -y --no-install-recommends noctalia noctalia-greeter

echo '[4/8] Normale Laufzeitpakete installieren'
missing=()
for package in "${runtime_apt[@]}"; do
  apt-cache show "$package" >/dev/null 2>&1 || missing+=("$package")
done
if ((${#missing[@]})); then
  printf 'Fehlende Paketnamen: %s\n' "${missing[*]}" >&2
  echo 'Abbruch ohne weitere Teilinstallation: erst Paketnamen/Quelle für dieses Debian-System prüfen.' >&2
  exit 1
fi
as_root apt-get install -y --no-install-recommends "${runtime_apt[@]}"

if ((build)); then
  echo '[5/8] Build-Abhängigkeiten installieren und lokale Pakete bauen'
  "$ROOT_DIR/scripts/02-install-dependencies.sh" --apply build
  WAREHOUSE_REUSE_WORK=1 "$ROOT_DIR/scripts/03-build-packages.sh"
  labwc_deb="$(latest_match "$local_labwc")"
  rmpc_deb="$(latest_match "$local_rmpc")"
fi

echo '[6/8] Lesbian-Labwc- und rmpc-Pakete installieren'
as_root apt-get install -y --no-install-recommends "$labwc_deb" "$rmpc_deb"

echo '[7/8] Benutzerprofil mit Backup ausrollen'
"$ROOT_DIR/scripts/deploy-lesbian-stable-config.sh" --apply

echo '[8/8] Noctalia Greeter als Display Manager einrichten'
as_root "$ROOT_DIR/scripts/07-install-noctalia-greeter.sh" --apply

if ((refind)); then
  echo '[rEFInd] Paket und Theme einrichten'
  [[ -d /sys/firmware/efi ]] || {
    echo 'Kein UEFI erkannt; rEFInd-Schritt abgebrochen.' >&2
    exit 1
  }
  mountpoint -q /boot/efi || {
    echo '/boot/efi ist nicht gemountet; rEFInd-Schritt abgebrochen.' >&2
    exit 1
  }
  as_root apt-get install -y --no-install-recommends refind
  stamp="$(date +%Y%m%d-%H%M%S)"
  refind_root="/boot/efi/EFI/refind"
  refind_backup="/var/backups/lesbian-stable-refind/$stamp"
  as_root install -d -m 0700 "$refind_backup"
  if as_root test -e "$refind_root/refind.conf"; then
    as_root cp -a "$refind_root/refind.conf" "$refind_backup/refind.conf"
  fi
  refind_install="$(command -v refind-install || true)"
  [[ -n $refind_install ]] || { echo 'refind-install wurde vom Paket nicht bereitgestellt.' >&2; exit 1; }
  as_root "$refind_install" --yes
  as_root install -d -m 0755 "$refind_root/themes/rEFInd-lesbian-singularity"
  as_root cp -a "$ROOT_DIR/sources/refind/rEFInd-lesbian-singularity/." \
    "$refind_root/themes/rEFInd-lesbian-singularity/"
  as_root install -m 0644 "$ROOT_DIR/sources/refind/refind.conf" "$refind_root/refind.conf"
  echo "rEFInd-Theme installiert. Sicherung: $refind_backup"
  echo 'rEFInd wurde mit --yes auf der geprüften ESP installiert und als EFI-Eintrag eingerichtet.'
fi

echo
echo 'Lesbian Stable ist installiert.'
echo 'Abmelden und im Greeter die Session „labwc - lesbian singularity x7“ wählen.'
echo 'Die Änderungen werden erst nach einem neuen Login vollständig sichtbar.'
