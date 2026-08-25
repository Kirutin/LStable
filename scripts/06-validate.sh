#!/usr/bin/env bash
# The compact checks deliberately use command && success || failure.
# shellcheck disable=SC2015
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0
warnings=0
ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARNUNG] %s\n' "$*"; warnings=$((warnings + 1)); }
fail() { printf '[FEHLER] %s\n' "$*"; failures=$((failures + 1)); }

printf 'Lesbian Stable Validierung\n\n'

for file in \
  "$HOME/.config/labwc/rc.xml" \
  "$HOME/.config/labwc/menu.xml" \
  "$HOME/.local/state/noctalia/settings.toml" \
  "$HOME/.local/share/themes/Noctalia-Cyberpunk/openbox-3/themerc" \
  "$HOME/.config/fastfetch/config.jsonc" \
  "$HOME/.config/yazi/yazi.toml" \
  "$HOME/.config/yazi/theme.toml" \
  "$HOME/.config/mpd/mpd.conf" \
  "$HOME/.config/mpDris2/mpDris2.conf" \
  "$HOME/.config/rmpc/config.ron" \
  "$HOME/.config/rmpc/themes/warehouse13.ron"
do
  [[ -f $file ]] && ok "$file" || fail "$file fehlt"
done

if rg -n '@@(HOME|OUTPUT|MODE|WEATHER_LOCATION|DOWNLOADS|DOCUMENTS|PICTURES|VIDEOS|PROJECTS)@@' \
    "$HOME/.config/labwc" "$HOME/.local/state/noctalia/settings.toml" \
    "$HOME/.config/fastfetch" \
    "$HOME/.config/mpd" "$HOME/.config/mpDris2" "$HOME/.config/rmpc" 2>/dev/null; then
  fail 'Nicht ersetzte Vorlagenwerte gefunden'
else
  ok 'Keine Vorlagenwerte in aktiven Konfigurationen'
fi

if python3 - "$HOME/.config/labwc/rc.xml" "$HOME/.config/labwc/menu.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
for path in sys.argv[1:]:
    ET.parse(path)
PY
then
  ok 'Labwc-XML ist syntaktisch gueltig'
else
  fail 'Labwc-XML ist ungueltig'
fi

version="$(labwc --version 2>/dev/null | head -1)"
if [[ $version == 'labwc 0.20.2'* && $version != *dirty* && $version != *hyflair* ]]; then
  ok "Saubere Version: $version"
else
  fail "Unerwartete Labwc-Version: ${version:-nicht gefunden}"
fi

grep -q 'XKB_DEFAULT_LAYOUT=de' "$HOME/.config/labwc/environment" && \
  grep -q 'XKB_DEFAULT_VARIANT=nodeadkeys' "$HOME/.config/labwc/environment" && \
  ok 'Deutsch nodeadkeys gespeichert' || fail 'Deutsch nodeadkeys fehlt'

grep -q '<cornerRadius>16</cornerRadius>' "$HOME/.config/labwc/rc.xml" && \
  grep -q 'border.width: 3' "$HOME/.local/share/themes/Noctalia-Cyberpunk/openbox-3/themerc" && \
  grep -q 'window.active.border.color: #ee0f54,#dc2683,#a855f7' "$HOME/.local/share/themes/Noctalia-Cyberpunk/openbox-3/themerc" && \
  ok 'Radius und mehrfarbiger 3-Pixel-Rahmen gespeichert' || fail 'Fensterstil weicht ab'

[[ -x /usr/bin/noctalia ]] && ok 'Upstream-Noctalia installiert' || fail 'Noctalia fehlt'
ok 'CyLab, Tiling-Layer und Workspace-Overview sind bewusst nicht installiert'

if python3 - "$HOME/.config/yazi/yazi.toml" "$HOME/.config/yazi/theme.toml" <<'PY'
import sys
import tomllib
for path in sys.argv[1:]:
    with open(path, "rb") as handle:
        tomllib.load(handle)
PY
then
  ok 'Yazi-Konfiguration ist syntaktisch gueltig'
else
  fail 'Yazi-Konfiguration ist ungueltig'
fi

for command in dolphin kate gwenview plasma-discover fastfetch yazi ya mpd rmpc \
  mpDris2 yt-dlp ffmpeg wpctl pactl aplay pw-play; do
  command -v "$command" >/dev/null 2>&1 && ok "$command vorhanden" || fail "$command fehlt"
done
xfce_packages="$(
  dpkg-query -W -f='${binary:Package} ${db:Status-Abbrev}\n' \
    'xfce*' 'libxfce*' 'thunar*' 'libthunar*' 'exo*' 'libexo*' \
    'garcon*' 'libgarcon*' xfconf xfdesktop4 xfwm4 2>/dev/null | \
    awk '$2 ~ /^ii/ {print $1}' || true
)"
if [[ -z $xfce_packages ]]; then
  ok 'Keine Xfce- oder Thunar-Pakete installiert'
else
  fail "Unerwartete Xfce-Pakete: $xfce_packages"
fi
plasma_session_packages=""
for package in plasma-desktop plasma-workspace kwin-wayland kwin-x11 sddm; do
  status="$(dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null || true)"
  [[ $status == ii* ]] && plasma_session_packages+=" $package"
done
if [[ -z $plasma_session_packages ]]; then
  ok 'Kein Plasma-Desktop, KWin oder SDDM installiert'
else
  fail "Unerwartete Plasma-Sitzungspakete:$plasma_session_packages"
fi
icon_theme="$(awk -F= '
  /^\[Icons\]$/ { in_icons=1; next }
  /^\[/ { in_icons=0 }
  in_icons && $1 == "Theme" { print $2; exit }
' "$HOME/.config/kdeglobals" 2>/dev/null || true)"
if [[ $icon_theme == breeze-dark ]] && \
    [[ -f /usr/share/icons/breeze-dark/index.theme ]] && \
    [[ -f /usr/share/icons/breeze/places/64/folder.svg ]] && \
    [[ -f /usr/lib/x86_64-linux-gnu/qt6/plugins/iconengines/libqsvgicon.so ]]; then
  ok 'Breeze Dark mit Ordnericons ist fuer KDE/Qt aktiviert'
else
  fail "KDE-Icon-Theme unvollstaendig oder falsch: ${icon_theme:-nicht gesetzt}"
fi
if [[ -f $HOME/.config/menus/applications.menu ]] && \
    [[ $(xdg-mime query default image/png 2>/dev/null) == org.kde.gwenview.desktop ]] && \
    [[ $(xdg-mime query default image/jpeg 2>/dev/null) == org.kde.gwenview.desktop ]]; then
  ok 'KDE-Anwendungsmenue und Gwenview-Bildzuordnung sind aktiv'
else
  fail 'KDE-Anwendungsmenue oder Gwenview-Bildzuordnung fehlt'
fi
if find /usr/share/wayland-sessions /usr/share/xsessions -maxdepth 1 -type f \
    \( -iname '*xfce*.desktop' -o -iname 'plasma*.desktop' \) \
    -print -quit 2>/dev/null | grep -q .; then
  fail 'Unerwartete Xfce- oder Plasma-Anmeldesitzung vorhanden'
else
  ok 'Nur der Labwc-Stack ist als Desktop vorgesehen'
fi
rmpc version 2>/dev/null | grep -q '^rmpc 0\.11\.0 ' && \
  ok 'rmpc 0.11.0 installiert' || fail 'Unerwartete rmpc-Version'
fastfetch --pipe >/dev/null 2>&1 && ok 'Fastfetch-Konfiguration laeuft' || fail 'Fastfetch-Konfiguration fehlerhaft'
grep -Fq "music_directory        \"$HOME/Musik\"" "$HOME/.config/mpd/mpd.conf" && \
  ok "MPD-Musikordner ist $HOME/Musik" || fail 'MPD-Musikordner weicht ab'

for service in pipewire.service wireplumber.service pipewire-pulse.service; do
  if systemctl --user is-active --quiet "$service"; then
    ok "$service laeuft"
  else
    fail "$service laeuft nicht"
  fi
done
if wpctl get-volume @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1; then
  ok 'PipeWire hat einen Standard-Audioausgang'
else
  fail 'PipeWire hat keinen Standard-Audioausgang'
fi
default_sink="$(pactl get-default-sink 2>/dev/null || true)"
if [[ -n $default_sink ]]; then
  ok "PulseAudio-Kompatibilitaet nutzt $default_sink"
else
  fail 'PulseAudio-Kompatibilitaet hat keinen Standard-Audioausgang'
fi

if systemctl --user is-active --quiet mpd.service; then
  ok 'MPD-Userdienst laeuft'
  rmpc status >/dev/null 2>&1 && ok 'rmpc erreicht MPD' || fail 'rmpc erreicht MPD nicht'
else
  fail 'MPD-Userdienst laeuft nicht'
fi
if systemctl --user is-active --quiet mpDris2.service; then
  ok 'mpDris2-Userdienst laeuft'
else
  fail 'mpDris2-Userdienst laeuft nicht'
fi
if busctl --user --no-pager list 2>/dev/null | grep -q 'org.mpris.MediaPlayer2.mpd'; then
  ok 'MPD ist ueber MPRIS sichtbar'
else
  fail 'MPD-MPRIS-Name fehlt'
fi

[[ -f /usr/share/wayland-sessions/labwc-lesbian-stable.desktop ]] && \
  ok 'Login-Session installiert' || fail 'Login-Session fehlt'

greeter_state_dir="$(stat -c '%U:%G:%a' /var/lib/noctalia-greeter 2>/dev/null || true)"
if [[ -x /usr/bin/noctalia-greeter-session ]] && \
    [[ -f "$ROOT_DIR/config-template/noctalia-greeter/greeter.toml" ]] && \
    [[ -f "$ROOT_DIR/assets/warehouse-13-lesbian-greeter-wallpaper.png" ]] && \
    [[ $greeter_state_dir == '_greetd:_greetd:750' ]]; then
  ok 'Noctalia Greeter und geschuetztes Warehouse-Theme installiert'
else
  fail "Noctalia Greeter oder geschuetztes Warehouse-Theme fehlt: ${greeter_state_dir:-unbekannt}"
fi
if [[ $(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null) == \
      /usr/lib/systemd/system/greetd.service ]] && systemctl is-enabled --quiet greetd.service; then
  ok 'greetd ist als Display-Manager fuer den naechsten Start aktiviert'
else
  fail 'greetd ist nicht als Display-Manager aktiviert'
fi

if [[ ${XDG_CURRENT_DESKTOP:-} == labwc ]]; then
  ok 'Laufende Labwc-Session erkannt'
  pgrep -u "$USER" -x noctalia >/dev/null 2>&1 && ok 'Noctalia laeuft' || fail 'Noctalia laeuft nicht'
  pgrep -u "$USER" -f polkit-kde-authentication-agent-1 >/dev/null 2>&1 && \
    ok 'KDE-Polkit-Agent laeuft' || fail 'KDE-Polkit-Agent laeuft nicht'
  command -v wlr-randr >/dev/null 2>&1 && wlr-randr || warn 'wlr-randr fehlt'
  warn 'Overview, Fensterrahmen, Rundungen, Zonen und KDE-Darkmode muessen jetzt noch sichtbar geprueft werden.'
else
  warn 'Keine laufende Labwc-Session. Sichtbare Laufzeitpruefung steht noch aus.'
fi

command -v kitty >/dev/null 2>&1 && ok 'Kitty vorhanden' || fail 'Kitty fehlt'

if apt-get -o Debug::NoLocking=true check >/dev/null 2>&1; then
  ok 'APT-Paketstatus ist konsistent'
else
  fail 'APT meldet Paketprobleme'
fi

printf '\nErgebnis: %d Fehler, %d Warnungen.\n' "$failures" "$warnings"
((failures == 0))
