#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="$ROOT_DIR/config-template"
apply=0
output="${LESBIAN_STABLE_OUTPUT:-}"
weather="${LESBIAN_STABLE_WEATHER_LOCATION:-}"

while (($#)); do
  case "$1" in
    --apply) apply=1; shift ;;
    --output) output="${2:?Ausgang nach --output fehlt}"; shift 2 ;;
    --mode) shift 2 ;; # accepted for compatibility; Labwc now chooses 1920x1080 dynamically
    --weather-location) weather="${2:?Ort nach --weather-location fehlt}"; shift 2 ;;
    -h|--help)
      cat <<'EOF'
Aufruf: deploy-lesbian-stable-config.sh [--apply] [--output NAME]

Ohne --apply bleibt der Lauf eine Vorschau. Vorhandene Benutzerdateien werden
beim Anwenden unter ~/.local/state/lesbian-stable-backups/ gesichert.
EOF
      exit 0
      ;;
    *) echo "Unbekannte Option: $1" >&2; exit 2 ;;
  esac
done

[[ $EUID -ne 0 ]] || {
  echo 'Die Benutzerkonfiguration darf nicht als root ausgerollt werden.' >&2
  exit 1
}

for required in \
  "$TEMPLATE_DIR/lesbian-stable/labwc/rc.xml" \
  "$TEMPLATE_DIR/lesbian-stable/labwc/menu.xml" \
  "$TEMPLATE_DIR/noctalia/settings.toml" \
  "$TEMPLATE_DIR/noctalia/palettes/Warehouse-13-Lesbian.json" \
  "$ROOT_DIR/assets/warehouse-13-lesbian-cyberpunk-wallpaper.png" \
  "$ROOT_DIR/assets/warehouse-13-lesbian-greeter-wallpaper.png"
do
  [[ -f $required ]] || { echo "Fehlende Projektdatei: $required" >&2; exit 1; }
done

if [[ -z $output ]] && command -v wlr-randr >/dev/null 2>&1 && [[ -n ${WAYLAND_DISPLAY:-} ]]; then
  output="$(wlr-randr 2>/dev/null | awk '/^[^[:space:]]+[[:space:]]/ {print $1; exit}' || true)"
fi
output="${output:-HEADLESS-1}"

echo 'Lesbian Stable Benutzerprofil'
echo "  Zielbenutzer: $USER"
echo "  Wayland-Ausgang: $output"
echo "  Wetterort: ${weather:-nicht gesetzt}"
echo '  Umfang: Labwc-Stil, Noctalia, Greeter-Dotfiles, Qt/GTK, Terminal/Musik, Firefox'
echo '  Bewusst nicht enthalten: HyFlair, CyLab, Tiling-Layer, Workspace-Overview'

if ((apply == 0)); then
  cat <<'EOF'

Trockenlauf. Es wurden keine Dateien geändert.
Zum Anwenden denselben Befehl mit --apply erneut starten.
EOF
  exit 0
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="$HOME/.local/state/lesbian-stable-backups/$timestamp"
render_dir="$(mktemp -d)"
trap 'rm -rf "$render_dir"' EXIT

render() {
  local source="$1" destination="$2"
  python3 - "$source" "$destination" "$HOME" "$output" "$weather" <<'PY'
from pathlib import Path
import sys

source, destination, home, output, weather = sys.argv[1:]
text = Path(source).read_text(encoding="utf-8")
for old, new in {
    "@@HOME@@": home,
    "@@OUTPUT@@": output,
    "@@WEATHER_LOCATION@@": weather,
}.items():
    text = text.replace(old, new)
Path(destination).parent.mkdir(parents=True, exist_ok=True)
Path(destination).write_text(text, encoding="utf-8")
PY
}

backup_and_install() {
  local source="$1" target="$2" mode_bits="${3:-0644}"
  local relative="${target#"$HOME"/}"
  if [[ -e $target || -L $target ]]; then
    mkdir -p "$backup_root/$(dirname "$relative")"
    cp -a "$target" "$backup_root/$relative"
  fi
  install -D -m "$mode_bits" "$source" "$target"
}

render "$TEMPLATE_DIR/lesbian-stable/labwc/menu.xml" "$render_dir/labwc/menu.xml"
render "$TEMPLATE_DIR/noctalia/settings.toml" "$render_dir/noctalia/settings.toml"
render "$TEMPLATE_DIR/fastfetch/config.jsonc" "$render_dir/fastfetch/config.jsonc"
render "$TEMPLATE_DIR/mpd/mpd.conf" "$render_dir/mpd/mpd.conf"
render "$TEMPLATE_DIR/mpDris2/mpDris2.conf" "$render_dir/mpDris2/mpDris2.conf"
render "$TEMPLATE_DIR/rmpc/config.ron" "$render_dir/rmpc/config.ron"

mkdir -p "$HOME/Musik" "$HOME/Musik/Lyrics" \
  "$HOME/.local/share/mpd/playlists" "$HOME/.local/state/mpd" "$HOME/.cache/rmpc"

for name in rc.xml environment keybindings.md; do
  backup_and_install "$TEMPLATE_DIR/lesbian-stable/labwc/$name" "$HOME/.config/labwc/$name"
done
backup_and_install "$TEMPLATE_DIR/lesbian-stable/labwc/autostart" "$HOME/.config/labwc/autostart" 0755
backup_and_install "$render_dir/labwc/menu.xml" "$HOME/.config/labwc/menu.xml"
for name in applications.py recent-files.py; do
  backup_and_install "$TEMPLATE_DIR/labwc/pipe-menus/$name" "$HOME/.config/labwc/pipe-menus/$name" 0755
done

for name in state.toml wallpaper-vibrant-current.json; do
  backup_and_install "$TEMPLATE_DIR/noctalia/$name" "$HOME/.local/state/noctalia/$name"
done
backup_and_install "$render_dir/noctalia/settings.toml" "$HOME/.local/state/noctalia/settings.toml"
backup_and_install "$TEMPLATE_DIR/noctalia/palettes/Warehouse-13-Lesbian.json" \
  "$HOME/.config/noctalia/palettes/Warehouse-13-Lesbian.json"
for name in plugin.toml bridge.luau heart.luau README.md; do
  backup_and_install "$ROOT_DIR/sources/plugins/lesbian-heart-visualizer/$name" \
    "$HOME/.local/share/noctalia/plugins/lesbian-heart-visualizer/$name"
done
backup_and_install "$ROOT_DIR/sources/plugins/lesbian-heart-visualizer/translations/en.json" \
  "$HOME/.local/share/noctalia/plugins/lesbian-heart-visualizer/translations/en.json"

backup_and_install "$TEMPLATE_DIR/ghostty/config" "$HOME/.config/ghostty/config"
backup_and_install "$TEMPLATE_DIR/ghostty/themes/noctalia" "$HOME/.config/ghostty/themes/noctalia"
backup_and_install "$TEMPLATE_DIR/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
backup_and_install "$TEMPLATE_DIR/kitty/themes/warehouse13-lesbian.conf" \
  "$HOME/.config/kitty/themes/warehouse13-lesbian.conf"
backup_and_install "$render_dir/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
backup_and_install "$ROOT_DIR/assets/kiru-fastfetch-lesbian-precomp.png" \
  "$HOME/.config/fastfetch/kiru-fastfetch-lesbian-precomp.png"
backup_and_install "$TEMPLATE_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
backup_and_install "$TEMPLATE_DIR/bash/warehouse13-starship.bash" \
  "$HOME/.config/bash/warehouse13-starship.bash"
backup_and_install "$TEMPLATE_DIR/btop/themes/kiru-cyberpunk.theme" \
  "$HOME/.config/btop/themes/kiru-cyberpunk.theme"
backup_and_install "$TEMPLATE_DIR/btop/btop.conf" "$HOME/.config/btop/btop.conf"
backup_and_install "$render_dir/mpd/mpd.conf" "$HOME/.config/mpd/mpd.conf"
backup_and_install "$render_dir/mpDris2/mpDris2.conf" "$HOME/.config/mpDris2/mpDris2.conf"
backup_and_install "$render_dir/rmpc/config.ron" "$HOME/.config/rmpc/config.ron"
backup_and_install "$TEMPLATE_DIR/rmpc/themes/warehouse13.ron" "$HOME/.config/rmpc/themes/warehouse13.ron"
backup_and_install "$TEMPLATE_DIR/yazi/yazi.toml" "$HOME/.config/yazi/yazi.toml"
backup_and_install "$TEMPLATE_DIR/yazi/theme.toml" "$HOME/.config/yazi/theme.toml"
backup_and_install "$TEMPLATE_DIR/systemd/user/mpDris2.service.d/warehouse13.conf" \
  "$HOME/.config/systemd/user/mpDris2.service.d/warehouse13.conf"

backup_and_install "$ROOT_DIR/assets/warehouse-13-lesbian-cyberpunk-wallpaper.png" \
  "$HOME/.local/share/lesbian-stable/wallpapers/lesbian-stable-wallpaper.png"
backup_and_install "$TEMPLATE_DIR/themes/Noctalia-Cyberpunk/openbox-3/themerc" \
  "$HOME/.local/share/themes/Noctalia-Cyberpunk/openbox-3/themerc"
backup_and_install "$TEMPLATE_DIR/themes/Warehouse-13-Lesbian/gtk-3.0/gtk.css" \
  "$HOME/.local/share/themes/Warehouse-13-Lesbian/gtk-3.0/gtk.css"
backup_and_install "$TEMPLATE_DIR/kde/noctalia.colors" "$HOME/.local/share/color-schemes/noctalia.colors"
backup_and_install "$TEMPLATE_DIR/qt5ct/colors/noctalia.conf" "$HOME/.config/qt5ct/colors/noctalia.conf"
backup_and_install "$TEMPLATE_DIR/qt6ct/colors/noctalia.conf" "$HOME/.config/qt6ct/colors/noctalia.conf"
backup_and_install "$TEMPLATE_DIR/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
backup_and_install "$TEMPLATE_DIR/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
backup_and_install "$TEMPLATE_DIR/menus/applications.menu" "$HOME/.config/menus/applications.menu"

# shellcheck disable=SC2016
starship_source='[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/bash/warehouse13-starship.bash" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/bash/warehouse13-starship.bash"'
if ! grep -Fqx "$starship_source" "$HOME/.bashrc" 2>/dev/null; then
  if [[ -e $HOME/.bashrc ]]; then
    mkdir -p "$backup_root"
    cp -a "$HOME/.bashrc" "$backup_root/.bashrc"
  fi
  printf '\n%s\n%s\n' '# Lesbian Stable Starship prompt' "$starship_source" >> "$HOME/.bashrc"
fi

if command -v xdg-mime >/dev/null 2>&1; then
  for mime in image/avif image/bmp image/gif image/heif image/jpeg image/jxl image/png image/svg+xml image/tiff image/webp; do
    xdg-mime default org.kde.gwenview.desktop "$mime" || true
  done
fi
if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

if systemctl --user show-environment >/dev/null 2>&1; then
  systemctl --user daemon-reload
  systemctl --user enable --now \
    pipewire.socket pipewire.service wireplumber.service \
    pipewire-pulse.socket pipewire-pulse.service mpd.service mpDris2.service
else
  echo 'Hinweis: Kein laufender systemd-Usermanager; Dienste werden beim ersten Login aktiviert.'
fi

echo
echo "Lesbian Stable Benutzerprofil installiert. Sicherung: $backup_root"
echo 'Die Labwc-Session heißt labwc-lesbian-stable.'
