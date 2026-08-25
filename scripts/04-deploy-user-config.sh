#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Compatibility entrypoint: the former script deployed HyFlair state. Keep
# its filename for old notes, but route every invocation to the clean profile.
# shellcheck disable=SC2093
exec "$ROOT_DIR/scripts/deploy-lesbian-stable-config.sh" "$@"

TEMPLATE_DIR="$ROOT_DIR/config-template"
apply=0
output=""
mode=""
weather=""

while (($#)); do
  case "$1" in
    --apply) apply=1; shift ;;
    --output) output="${2:?Ausgang nach --output fehlt}"; shift 2 ;;
    --mode) mode="${2:?Modus nach --mode fehlt}"; shift 2 ;;
    --weather-location) weather="${2:?Ort nach --weather-location fehlt}"; shift 2 ;;
    -h|--help)
      echo "Aufruf: $0 [--apply] --output NAME --mode BREITExHOEHE@HZ [--weather-location ORT]"
      exit 0
      ;;
    *) echo "Unbekannte Option: $1" >&2; exit 2 ;;
  esac
done

if [[ -z $output || -z $mode ]]; then
  echo 'Ausgang und Modus muessen explizit angegeben werden.' >&2
  echo "Beispiel fuer den bekannten AOC: $0 --output HDMI-A-1 --mode 3440x1440@100.000Hz" >&2
  exit 2
fi

echo "Zielbenutzer: $USER"
echo "Home: $HOME"
echo "Ausgang: $output"
echo "Modus: $mode"
echo "Wetterort: ${weather:-nicht gesetzt}"

if command -v wlr-randr >/dev/null 2>&1 && [[ -n ${WAYLAND_DISPLAY:-} ]]; then
  randr="$(wlr-randr 2>/dev/null || true)"
  if [[ -n $randr ]]; then
    grep -q "^${output}[[:space:]]" <<<"$randr" || {
      echo "Der Ausgang $output wurde von wlr-randr nicht gemeldet." >&2
      exit 1
    }
    resolution="${mode%@*}"
    refresh="${mode#*@}"
    refresh="${refresh%Hz}"
    if ! grep -Fq "$resolution" <<<"$randr" || \
        ! grep -Fq "${refresh%%.*}" <<<"$randr"; then
      echo "Aufloesung oder Bildwiederholrate aus $mode wurde von wlr-randr nicht angeboten." >&2
      exit 1
    fi
  fi
fi

if ((apply == 0)); then
  echo
  echo 'Trockenlauf. Es wurde nichts kopiert.'
  echo 'Nach Pruefung erneut mit --apply starten.'
  exit 0
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="$HOME/.local/state/warehouse-13-backups/$timestamp"
render_dir="$(mktemp -d)"
trap 'rm -rf "$render_dir"' EXIT

xdg_dir() {
  local key="$1" fallback="$2" value=""
  if command -v xdg-user-dir >/dev/null 2>&1; then
    value="$(xdg-user-dir "$key" 2>/dev/null || true)"
  fi
  printf '%s' "${value:-$fallback}"
}

downloads="$(xdg_dir DOWNLOAD "$HOME/Downloads")"
documents="$(xdg_dir DOCUMENTS "$HOME/Documents")"
pictures="$(xdg_dir PICTURES "$HOME/Pictures")"
videos="$(xdg_dir VIDEOS "$HOME/Videos")"
music="$(xdg_dir MUSIC "$HOME/Musik")"
if [[ -d $HOME/Projekte ]]; then
  projects="$HOME/Projekte"
else
  projects="$HOME/Projects"
fi

render() {
  local source="$1" destination="$2"
  python3 - "$source" "$destination" "$HOME" "$output" "$mode" "$weather" \
    "$downloads" "$documents" "$pictures" "$videos" "$projects" "$music" <<'PY'
from pathlib import Path
import sys

source, destination, home, output, mode, weather, downloads, documents, pictures, videos, projects, music = sys.argv[1:]
text = Path(source).read_text(encoding="utf-8")
for old, new in {
    "@@HOME@@": home,
    "@@OUTPUT@@": output,
    "@@MODE@@": mode,
    "@@WEATHER_LOCATION@@": weather,
    "@@DOWNLOADS@@": downloads,
    "@@DOCUMENTS@@": documents,
    "@@PICTURES@@": pictures,
    "@@VIDEOS@@": videos,
    "@@PROJECTS@@": projects,
    "@@MUSIC@@": music,
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

set_ini_value() {
  local path="$1" section="$2" key="$3" value="$4"
  python3 - "$path" "$section" "$key" "$value" <<'PY'
from pathlib import Path
import sys

path, section, key, value = sys.argv[1:]
target = Path(path)
lines = target.read_text(encoding="utf-8").splitlines() if target.exists() else []
header = f"[{section}]"
start = next((i for i, line in enumerate(lines) if line.strip() == header), None)

if start is None:
    if lines and lines[-1]:
        lines.append("")
    lines.extend((header, f"{key}={value}"))
else:
    end = next(
        (i for i in range(start + 1, len(lines)) if lines[i].startswith("[")),
        len(lines),
    )
    existing = next(
        (i for i in range(start + 1, end) if lines[i].split("=", 1)[0] == key),
        None,
    )
    if existing is None:
        lines.insert(end, f"{key}={value}")
    else:
        lines[existing] = f"{key}={value}"

target.parent.mkdir(parents=True, exist_ok=True)
target.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

render "$TEMPLATE_DIR/labwc/menu.xml" "$render_dir/labwc/menu.xml"
render "$TEMPLATE_DIR/noctalia/settings.toml" "$render_dir/noctalia/settings.toml"
render "$TEMPLATE_DIR/fastfetch/config.jsonc" "$render_dir/fastfetch/config.jsonc"
render "$TEMPLATE_DIR/hyflair/outputs.json" "$render_dir/hyflair/outputs.json"
render "$TEMPLATE_DIR/mpd/mpd.conf" "$render_dir/mpd/mpd.conf"
render "$TEMPLATE_DIR/mpDris2/mpDris2.conf" "$render_dir/mpDris2/mpDris2.conf"
render "$TEMPLATE_DIR/rmpc/config.ron" "$render_dir/rmpc/config.ron"

mkdir -p "$music" "$music/Lyrics" \
  "$HOME/.local/share/mpd/playlists" "$HOME/.local/state/mpd" "$HOME/.cache/rmpc"

for name in rc.xml environment keybindings.md; do
  backup_and_install "$TEMPLATE_DIR/labwc/$name" "$HOME/.config/labwc/$name"
done
backup_and_install "$TEMPLATE_DIR/labwc/autostart" "$HOME/.config/labwc/autostart" 0755
backup_and_install "$render_dir/labwc/menu.xml" "$HOME/.config/labwc/menu.xml"
for name in applications.py recent-files.py; do
  backup_and_install "$TEMPLATE_DIR/labwc/pipe-menus/$name" \
    "$HOME/.config/labwc/pipe-menus/$name" 0755
done

backup_and_install "$TEMPLATE_DIR/hyflair/zones.json" "$HOME/.config/hyflair/zones.json"
backup_and_install "$render_dir/hyflair/outputs.json" "$HOME/.config/hyflair/outputs.json"

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
backup_and_install \
  "$ROOT_DIR/sources/plugins/lesbian-heart-visualizer/translations/en.json" \
  "$HOME/.local/share/noctalia/plugins/lesbian-heart-visualizer/translations/en.json"

backup_and_install "$TEMPLATE_DIR/ghostty/config" "$HOME/.config/ghostty/config"
backup_and_install "$TEMPLATE_DIR/ghostty/themes/noctalia" "$HOME/.config/ghostty/themes/noctalia"
backup_and_install "$render_dir/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
backup_and_install "$ROOT_DIR/assets/kiru-fastfetch-lesbian-precomp.png" \
  "$HOME/.config/fastfetch/kiru-fastfetch-lesbian-precomp.png"
backup_and_install "$TEMPLATE_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
backup_and_install "$TEMPLATE_DIR/bash/warehouse13-starship.bash" \
  "$HOME/.config/bash/warehouse13-starship.bash"
backup_and_install "$TEMPLATE_DIR/btop/themes/kiru-cyberpunk.theme" \
  "$HOME/.config/btop/themes/kiru-cyberpunk.theme"
backup_and_install "$TEMPLATE_DIR/btop/btop.conf" "$HOME/.config/btop/btop.conf"
backup_and_install "$TEMPLATE_DIR/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
backup_and_install "$TEMPLATE_DIR/kitty/themes/warehouse13-lesbian.conf" \
  "$HOME/.config/kitty/themes/warehouse13-lesbian.conf"
backup_and_install "$render_dir/mpd/mpd.conf" "$HOME/.config/mpd/mpd.conf"
backup_and_install "$render_dir/mpDris2/mpDris2.conf" "$HOME/.config/mpDris2/mpDris2.conf"
backup_and_install "$render_dir/rmpc/config.ron" "$HOME/.config/rmpc/config.ron"
backup_and_install "$TEMPLATE_DIR/rmpc/themes/warehouse13.ron" \
  "$HOME/.config/rmpc/themes/warehouse13.ron"
backup_and_install "$TEMPLATE_DIR/yazi/yazi.toml" "$HOME/.config/yazi/yazi.toml"
backup_and_install "$TEMPLATE_DIR/yazi/theme.toml" "$HOME/.config/yazi/theme.toml"
backup_and_install "$TEMPLATE_DIR/systemd/user/mpDris2.service.d/warehouse13.conf" \
  "$HOME/.config/systemd/user/mpDris2.service.d/warehouse13.conf"

backup_and_install "$ROOT_DIR/assets/warehouse-13-cyberpunk-wallpaper.png" \
  "$HOME/.local/share/warehouse-13/wallpapers/warehouse-13-cyberpunk-wallpaper.png"
backup_and_install "$ROOT_DIR/assets/warehouse-13-lesbian-cyberpunk-wallpaper.png" \
  "$HOME/.local/share/warehouse-13/wallpapers/warehouse-13-lesbian-cyberpunk-wallpaper.png"
backup_and_install "$TEMPLATE_DIR/themes/Noctalia-Cyberpunk/openbox-3/themerc" \
  "$HOME/.local/share/themes/Noctalia-Cyberpunk/openbox-3/themerc"
backup_and_install "$TEMPLATE_DIR/themes/Warehouse-13-Lesbian/gtk-3.0/gtk.css" \
  "$HOME/.local/share/themes/Warehouse-13-Lesbian/gtk-3.0/gtk.css"
backup_and_install "$TEMPLATE_DIR/kde/noctalia.colors" \
  "$HOME/.local/share/color-schemes/noctalia.colors"
backup_and_install "$TEMPLATE_DIR/qt5ct/colors/noctalia.conf" \
  "$HOME/.config/qt5ct/colors/noctalia.conf"
backup_and_install "$TEMPLATE_DIR/qt6ct/colors/noctalia.conf" \
  "$HOME/.config/qt6ct/colors/noctalia.conf"
backup_and_install "$TEMPLATE_DIR/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
backup_and_install "$TEMPLATE_DIR/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
backup_and_install "$TEMPLATE_DIR/menus/applications.menu" \
  "$HOME/.config/menus/applications.menu"

kdeglobals="$HOME/.config/kdeglobals"
if [[ -e $kdeglobals || -L $kdeglobals ]]; then
  mkdir -p "$backup_root/.config"
  cp -a "$kdeglobals" "$backup_root/.config/kdeglobals"
fi
set_ini_value "$kdeglobals" General ColorScheme Noctalia
set_ini_value "$kdeglobals" General Name noctalia
set_ini_value "$kdeglobals" General AccentColor '238,15,84'
set_ini_value "$kdeglobals" Icons Theme breeze-dark

mimeapps="$HOME/.config/mimeapps.list"
if [[ -e $mimeapps || -L $mimeapps ]]; then
  mkdir -p "$backup_root/.config"
  cp -a "$mimeapps" "$backup_root/.config/mimeapps.list"
fi
if command -v xdg-mime >/dev/null 2>&1; then
  for mime in \
    image/avif image/bmp image/gif image/heif image/jpeg image/jxl image/png \
    image/svg+xml image/tiff image/webp
  do
    xdg-mime default org.kde.gwenview.desktop "$mime"
  done
fi
if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental
fi

if systemctl --user show-environment >/dev/null 2>&1; then
  systemctl --user daemon-reload
  systemctl --user enable --now \
    pipewire.socket pipewire.service \
    wireplumber.service \
    pipewire-pulse.socket pipewire-pulse.service \
    mpd.service mpDris2.service
else
  echo 'Kein laufender systemd-Usermanager; Audio- und Musikdienste beim ersten Login aktivieren.'
fi

echo
echo "Konfiguration ausgerollt. Sicherung: $backup_root"
starship_source='[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/bash/warehouse13-starship.bash" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/bash/warehouse13-starship.bash"'
if ! grep -Fqx "$starship_source" "$HOME/.bashrc"; then
  mkdir -p "$backup_root"
  if [[ -e $HOME/.bashrc ]]; then
    cp -a "$HOME/.bashrc" "$backup_root/.bashrc"
  fi
  printf '\n%s\n%s\n' '# Warehouse 13 Starship prompt' "$starship_source" >>"$HOME/.bashrc"
fi
echo 'Starship wurde fuer interaktive Bash-Sitzungen aktiviert.'
if [[ ${mode%@*} != 1920x1080 ]]; then
  echo 'Hinweis: Die mitgelieferten Desktopwidget-Positionen sind fuer 1920x1080 angeordnet.'
fi
