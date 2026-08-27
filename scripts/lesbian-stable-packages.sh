#!/usr/bin/env bash
# Runtime packages for the portable, style-only Lesbian Stable profile.
# No desktop environment meta-package is intentionally listed here.
# shellcheck disable=SC2034

LESBIAN_STABLE_RUNTIME_PACKAGES=(
  ca-certificates wget
  greetd noctalia noctalia-greeter accountsservice
  lesbian-labwc kitty xwayland wlr-randr
  dbus-user-session qt5ct qt6ct qt6-wayland qt6-svg-plugins
  polkit-kde-agent-1 breeze breeze-gtk-theme breeze-icon-theme
  pipewire wireplumber pipewire-pulse pulseaudio-utils alsa-utils rtkit
  network-manager upower power-profiles-daemon brightnessctl
  wl-clipboard cliphist grim slurp swappy
  xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
  xdg-user-dirs xdg-utils
  dolphin kate gwenview plasma-discover kimageformat6-plugins
  qt6-image-formats-plugins firefox-esr fastfetch starship btop
  mpd mpdris2 yt-dlp ffmpeg
  ripgrep 7zip jq poppler-utils fd-find fzf zoxide yazi
  fonts-noto-core fonts-noto-color-emoji
)
