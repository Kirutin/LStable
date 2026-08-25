#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/SOURCE-PINS.env"

PACKAGE_NAME="lesbian-labwc"
UPSTREAM_VERSION="${LABWC_VERSION:-$LABWC_REF}"
PACKAGE_REVISION="${LABWC_PACKAGE_REVISION:-1lesbian1}"
PACKAGE_VERSION="${UPSTREAM_VERSION}-${PACKAGE_REVISION}"
PACKAGE_ARCH="${LABWC_ARCH:-amd64}"
MAINTAINER="Lesbian Stable Maintainers <noreply@example.com>"

WORKDIR="${LABWC_WORKDIR:-$ROOT_DIR/.work/lesbian-labwc}"
SOURCE_DIR="$WORKDIR/source"
BUILD_DIR="$WORKDIR/build"
PKG_DIR="$WORKDIR/package"
OUT_DIR="$ROOT_DIR/build/lesbian-labwc-deb"
OUT_DEB="$OUT_DIR/${PACKAGE_NAME}_${PACKAGE_VERSION}_${PACKAGE_ARCH}.deb"
PATCH_DIR="$ROOT_DIR/packaging/patches/labwc-lesbian"
WLROOTS_PATCH_DIR="$ROOT_DIR/packaging/patches/wlroots"

DEB_HOST_MULTIARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || echo x86_64-linux-gnu)"
JOBS="${LESBIAN_BUILD_JOBS:-2}"

log() { printf '\n[Lesbian Stable] %s\n' "$*"; }

clone_pinned() {
  local name="$1" bundle="$2" commit="$3" destination="$4"
  log "Bereite $name vor: $commit"
  # The labwc bundle is a release-only shallow bundle; the older fallback
  # bundles are repository bundles with no advertised HEAD.
  if [[ $name == labwc ]]; then
    git clone -q --depth=1 "$bundle" "$destination"
  else
    git clone -q "$bundle" "$destination"
  fi
  git -C "$destination" checkout -q --detach "$commit"
}

apply_series() {
  local source_dir="$1" patch_dir="$2" patch
  while IFS= read -r -d '' patch; do
    if git -C "$source_dir" apply --reverse --check "$patch" >/dev/null 2>&1; then
      continue
    fi
    log "Wende $(basename "$patch") an"
    git -C "$source_dir" apply --check "$patch"
    git -C "$source_dir" apply "$patch"
  done < <(find "$patch_dir" -maxdepth 1 -type f -name '*.patch' -print0 | sort -z)
}

detect_depends() {
  local soname library_path package
  local -a deps=(libc6 libdrm2 libwayland-client0 libwayland-server0
    libxkbcommon0 libpixman-1-0 libinput10 libseat1 xwayland)

  while IFS= read -r soname; do
    [ -n "$soname" ] || continue
    library_path="$(/sbin/ldconfig -p | awk -v s="$soname" '$1 == s {print $NF; exit}')"
    [ -n "$library_path" ] || continue
    package="$(dpkg-query -S "$(readlink -f "$library_path")" 2>/dev/null | head -n1 | cut -d: -f1 || true)"
    [ -n "$package" ] && deps+=("$package")
  done < <(
    find "$PKG_DIR/usr" -type f -print0 |
      xargs -0 -r file |
      awk -F: '/ELF/ {print $1}' |
      xargs -r objdump -p 2>/dev/null |
      awk '$1 == "NEEDED" {print $2}' | sort -u
  )

  printf '%s\n' "${deps[@]}" | sort -u | paste -sd, - | sed 's/,/, /g'
}

log "Baue Upstream labwc $UPSTREAM_VERSION (ohne CyLab/Overview/HyFlair-Patches)"
rm -rf "$WORKDIR" "$OUT_DIR"
mkdir -p "$WORKDIR" "$OUT_DIR"

clone_pinned labwc "$ROOT_DIR/vendor/labwc-0.20.2.bundle" "$LABWC_COMMIT" "$SOURCE_DIR"
clone_pinned wlroots "$ROOT_DIR/vendor/wlroots-0.20.2.bundle" "$WLROOTS_COMMIT" "$SOURCE_DIR/subprojects/wlroots"
clone_pinned libsfdo "$ROOT_DIR/vendor/libsfdo-v0.1.4.bundle" "$LIBSFDO_COMMIT" "$SOURCE_DIR/subprojects/libsfdo"
clone_pinned libliftoff "$ROOT_DIR/vendor/libliftoff-9114b1e.bundle" "$LIBLIFTOFF_COMMIT" \
  "$SOURCE_DIR/subprojects/wlroots/subprojects/libliftoff"

apply_series "$SOURCE_DIR" "$PATCH_DIR"
apply_series "$SOURCE_DIR/subprojects/wlroots" "$WLROOTS_PATCH_DIR"
git -C "$SOURCE_DIR" diff --check

log "Konfiguriere Meson"
meson setup "$BUILD_DIR" "$SOURCE_DIR" \
  --buildtype=release \
  --prefix=/usr \
  --libdir="lib/$DEB_HOST_MULTIARCH" \
  -Dlesbian-version="$UPSTREAM_VERSION" \
  -Dman-pages="${LESBIAN_MAN_PAGES:-disabled}" \
  --wrap-mode=nodownload \
  --force-fallback-for=wlroots,libsfdo,libliftoff

log "Kompiliere labwc"
meson compile -C "$BUILD_DIR" -j "$JOBS"
"$BUILD_DIR/labwc" --version | grep -q "^labwc $UPSTREAM_VERSION "

log "Installiere in das Debian-Paket"
mkdir -p "$PKG_DIR/DEBIAN"
DESTDIR="$PKG_DIR" meson install --skip-subprojects -C "$BUILD_DIR"
mkdir -p "$PKG_DIR/usr/bin" "$PKG_DIR/usr/share/wayland-sessions" \
  "$PKG_DIR/usr/share/doc/$PACKAGE_NAME"

cat > "$PKG_DIR/usr/bin/start-labwc-lesbian-stable" <<'EOF'
#!/usr/bin/env bash
set -u

export XDG_CURRENT_DESKTOP=labwc
export XDG_SESSION_DESKTOP=labwc-lesbian-stable
export DESKTOP_SESSION=labwc-lesbian-stable
export XDG_SESSION_TYPE=wayland
export XKB_DEFAULT_LAYOUT="${XKB_DEFAULT_LAYOUT:-de}"
export XKB_DEFAULT_VARIANT="${XKB_DEFAULT_VARIANT:-nodeadkeys}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"
export GDK_BACKEND="${GDK_BACKEND:-wayland,x11}"
export MOZ_ENABLE_WAYLAND="${MOZ_ENABLE_WAYLAND:-1}"

if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment --systemd \
    WAYLAND_DISPLAY DISPLAY DBUS_SESSION_BUS_ADDRESS XDG_CURRENT_DESKTOP \
    XDG_SESSION_DESKTOP DESKTOP_SESSION XDG_SESSION_TYPE XKB_DEFAULT_LAYOUT \
    XKB_DEFAULT_VARIANT QT_QPA_PLATFORM GDK_BACKEND MOZ_ENABLE_WAYLAND \
    >/dev/null 2>&1 || true
fi

exec /usr/bin/labwc -s /usr/bin/labwc-lesbian-stable-autostart "$@"
EOF
chmod 0755 "$PKG_DIR/usr/bin/start-labwc-lesbian-stable"

cat > "$PKG_DIR/usr/bin/labwc-lesbian-stable-autostart" <<'EOF'
#!/usr/bin/env bash
set -u

export XDG_CURRENT_DESKTOP=labwc
export XDG_SESSION_DESKTOP=labwc-lesbian-stable
export DESKTOP_SESSION=labwc-lesbian-stable
export XDG_SESSION_TYPE=wayland
export XKB_DEFAULT_LAYOUT="${XKB_DEFAULT_LAYOUT:-de}"
export XKB_DEFAULT_VARIANT="${XKB_DEFAULT_VARIANT:-nodeadkeys}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"
export QT_QPA_PLATFORMTHEME="${QT_QPA_PLATFORMTHEME:-kde}"
export GDK_BACKEND="${GDK_BACKEND:-wayland,x11}"
export MOZ_ENABLE_WAYLAND="${MOZ_ENABLE_WAYLAND:-1}"
export TERMINAL="${TERMINAL:-ghostty}"

if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment --systemd \
    WAYLAND_DISPLAY DISPLAY DBUS_SESSION_BUS_ADDRESS XDG_CURRENT_DESKTOP \
    XDG_SESSION_DESKTOP DESKTOP_SESSION XDG_SESSION_TYPE XKB_DEFAULT_LAYOUT \
    XKB_DEFAULT_VARIANT QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME GDK_BACKEND \
    MOZ_ENABLE_WAYLAND TERMINAL >/dev/null 2>&1 || true
fi

# Only select 1920x1080 when the active monitor actually advertises it.
# This keeps VM and bare-metal sessions safe when the mode is unavailable.
if command -v wlr-randr >/dev/null 2>&1; then
  outputs="$(wlr-randr 2>/dev/null || true)"
  while IFS= read -r output; do
    [ -n "$output" ] || continue
    if printf '%s\n' "$outputs" | awk -v wanted="$output" '
      $1 == wanted { inside=1; next }
      inside && $0 !~ /^[[:space:]]/ { exit found ? 0 : 1 }
      inside && $1 == "1920x1080" { found=1 }
      END { exit found ? 0 : 1 }
    '; then
      wlr-randr --output "$output" --mode 1920x1080 \
        >/tmp/lesbian-stable-resolution.log 2>&1 || true
    fi
  done < <(printf '%s\n' "$outputs" | awk '/^[^[:space:]]/ {print $1}')
fi

if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY \
    >/dev/null 2>&1 || true
fi

if ! pgrep -u "${USER:-$(id -un)}" -f 'polkit-kde-authentication-agent-1' >/dev/null 2>&1; then
  for agent in \
    /usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1 \
    /usr/libexec/polkit-kde-authentication-agent-1 \
    /usr/lib/polkit-kde-authentication-agent-1
  do
    if [ -x "$agent" ]; then
      "$agent" >/tmp/lesbian-stable-polkit.log 2>&1 &
      break
    fi
  done
fi

if command -v noctalia >/dev/null 2>&1 && ! pgrep -u "${USER:-$(id -un)}" -x noctalia >/dev/null 2>&1; then
  noctalia --daemon >/tmp/lesbian-stable-noctalia.log 2>&1 &
fi
EOF
chmod 0755 "$PKG_DIR/usr/bin/labwc-lesbian-stable-autostart"

cat > "$PKG_DIR/usr/share/wayland-sessions/labwc-lesbian-stable.desktop" <<'EOF'
[Desktop Entry]
Name=labwc - lesbian singularity x7
Comment=Lesbian Stable style session powered by Labwc and Noctalia
Exec=/usr/bin/start-labwc-lesbian-stable
Type=Application
DesktopNames=labwc
Keywords=wayland;compositor;labwc;lesbian;stable;
EOF
cp -a "$PKG_DIR/usr/share/wayland-sessions/labwc-lesbian-stable.desktop" \
  "$PKG_DIR/usr/share/wayland-sessions/labwc-warehouse13.desktop"

cat > "$PKG_DIR/usr/share/doc/$PACKAGE_NAME/README.Debian" <<EOF
Lesbian Stable labwc $UPSTREAM_VERSION
======================================

This package contains upstream labwc $UPSTREAM_VERSION plus only the Lesbian
Stable visual patches: window opacity, rounded client corners, continuous
multicolor borders, rounded menus and rounded workspace OSD elements.

It deliberately does not contain CyLab, region snapping, workspace overview,
custom protocols or a tiling layer. Noctalia remains a separate package and is
started when available by the session wrapper.

The login session is named:

  labwc - Lesbian Stable
EOF

cat > "$PKG_DIR/usr/share/doc/$PACKAGE_NAME/copyright" <<EOF
Upstream: https://github.com/labwc/labwc/releases/tag/$UPSTREAM_VERSION
License: GPL-2.0-only
EOF

cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: $PACKAGE_NAME
Version: $PACKAGE_VERSION
Section: x11
Priority: optional
Architecture: $PACKAGE_ARCH
Maintainer: $MAINTAINER
Depends: $(detect_depends)
Provides: labwc
Conflicts: hyflair-labwc, labwc
Replaces: hyflair-labwc, labwc
Description: Lesbian Stable styled Labwc Wayland compositor
 Upstream labwc with the Lesbian Stable visual layer only.
 No CyLab, tiling layer or workspace overview is included.
EOF

find "$PKG_DIR" -type d -exec chmod 0755 {} +
find "$PKG_DIR" -type f ! -path '*/DEBIAN/*' -exec chmod 0644 {} +
chmod 0755 "$PKG_DIR/usr/bin/labwc" "$PKG_DIR/usr/bin/start-labwc-lesbian-stable"
chmod 0755 "$PKG_DIR/usr/bin/labwc-lesbian-stable-autostart"
dpkg-deb --root-owner-group --build "$PKG_DIR" "$OUT_DEB"
ln -sfn "$(basename "$OUT_DEB")" "$OUT_DIR/${PACKAGE_NAME}.deb"
sha256sum "$OUT_DEB"
