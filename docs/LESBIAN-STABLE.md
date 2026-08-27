# Lesbian Stable – Labwc 0.20.2

Lesbian Stable ist die reine Labwc-Style-Schicht des Desktops. Sie baut
Upstream-Labwc 0.20.2 mit wlroots 0.20.2 und den lokalen visuellen Patches:

- Fenstertransparenz fuer aktive und inaktive Fenster
- runde Client-Ecken und runde Fokusrahmen
- kontinuierliche mehrfarbige Fensterrahmen
- runde Menues und Workspace-OSD-Elemente

CyLab, HyFlair-Zonen, Tiling-Layer und Workspace-Overview sind absichtlich
nicht enthalten. Noctalia, der Noctalia Greeter sowie die Qt-/Terminal-
Konfigurationen bleiben getrennte Schichten.

## Reproduzierbarer Build

Im Paketordner:

```bash
./scripts/03-build-packages.sh
```

Der Labwc-Build verwendet die gepinnten Bundles und erzeugt:

```text
sources/build/lesbian-labwc-deb/lesbian-labwc_0.20.2-1lesbian2_amd64.deb
```

Vor einer Installation prüfen:

```bash
dpkg-deb -f sources/build/lesbian-labwc-deb/lesbian-labwc_*.deb Package Version Depends
dpkg-deb -c sources/build/lesbian-labwc-deb/lesbian-labwc_*.deb | grep -Ei 'hyflair|cylab|overview|zone'
```

Die zweite Prüfung muss keine Treffer liefern. Erst danach zeigt
`./scripts/05-install-built-packages.sh` einen APT-Trockenlauf; mit
`--apply` wird nach ausdrücklicher Zustimmung installiert. Das Paket ersetzt
den bisherigen `hyflair-labwc`-Stand und stellt die Session
`labwc-lesbian-stable` bereit.

## Installation auf einem anderen Debian-System

Der empfohlene Einstieg ist der neue, sichere Orchestrator:

```bash
./scripts/install-lesbian-stable.sh
./scripts/install-lesbian-stable.sh --apply --build
```

Der erste Aufruf zeigt nur die Paket- und Änderungsplanung. Der zweite richtet
das Noctalia-Repository ein, installiert ausschließlich die aufgelisteten
Laufzeitpakete, baut die lokalen Labwc-/rmpc-Pakete, rollt die Dotfiles mit
Backups aus und aktiviert den Noctalia Greeter. Es werden weder Plasma als
Desktop noch Xfce, HyFlair, CyLab, Tiling oder Workspace-Overview installiert.

Der Bootloader ist eine eigene Sicherheitsstufe. Das rEFInd-Theme liegt unter
`sources/refind/`; der EFI-Schritt wird nur mit `--refind` aktiviert und prüft
UEFI sowie eine gemountete ESP. Bestehende `refind.conf`-Dateien werden vor dem
Kopieren unter `/var/backups/lesbian-stable-refind/` gesichert; danach wird
`refind-install` auf der geprüften ESP mit der expliziten Bestätigung `--yes`
ausgeführt.
