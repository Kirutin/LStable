#!/usr/bin/env bash
# This file is sourced by the installer and preflight scripts.
# shellcheck disable=SC2034

BUILD_PACKAGES=(
  git build-essential cmake meson ninja-build pkgconf scdoc dpkg-dev file
  rsync shellcheck lintian patchelf gettext
  wayland-protocols libwayland-dev libxkbcommon-dev libinput-dev
  libpixman-1-dev libcairo2-dev libpango1.0-dev libdrm-dev libgbm-dev
  libegl-dev libgles2-mesa-dev libepoxy-dev libudev-dev libseat-dev
  libdisplay-info-dev libliftoff-dev hwdata
  libpipewire-0.3-dev libspa-0.2-dev libwireplumber-0.5-dev
  libsystemd-dev libdbus-1-dev libsdbus-c++-dev
  libfontconfig-dev libfreetype-dev libharfbuzz-dev librsvg2-dev
  libsecret-1-dev libsodium-dev libpolkit-agent-1-dev
  libpolkit-gobject-1-dev libpam0g-dev libcurl4-gnutls-dev libqalculate-dev
  libxml2-dev libmd4c-dev nlohmann-json3-dev libtomlplusplus-dev
  libical-dev libwebp-dev libjxl-dev libsndfile1-dev libjemalloc-dev
  libmagic-dev libzip-dev libpugixml-dev libjpeg-dev libpng-dev
  libsfdo-dev libxcb1-dev libxcb-ewmh-dev libxcb-icccm4-dev
  libxcb-composite0-dev libxcb-present-dev libxcb-res0-dev libxcb-xinput-dev
  libxcb-xfixes0-dev libxcb-errors-dev
)

RUNTIME_PACKAGES=(
  greetd noctalia-greeter accountsservice
  xwayland wlr-randr python3 python3-lxml python3-pil python3-pyqt6
  qt6-wayland qt6-svg-plugins ripgrep
  plasma-integration polkit-kde-agent-1 breeze breeze-gtk-theme
  breeze-icon-theme dbus-user-session
  pipewire wireplumber pipewire-pulse pulseaudio-utils alsa-utils rtkit
  network-manager upower power-profiles-daemon
  brightnessctl wl-clipboard cliphist grim slurp swappy
  xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
  xdg-user-dirs xdg-utils
  dolphin kate gwenview plasma-discover kimageformat6-plugins
  qt6-image-formats-plugins firefox-esr fastfetch starship btop
  mpd mpdris2 yt-dlp ffmpeg
  ripgrep wl-clipboard 7zip jq poppler-utils fd-find fzf zoxide yazi
  fonts-noto-core fonts-noto-color-emoji
)
