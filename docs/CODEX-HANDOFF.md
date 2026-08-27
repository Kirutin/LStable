# Codex handoff — Lesbian Stable QA state (2026-08-27)

This note documents the changes made during the Debian 13 clean-install regression work on branch `codex/public-setup`, why they were needed, what is verified now, and what remains open after the first successful boot.

## Project boundary

Lesbian Stable is **not** a Debian fork or a new distribution. It is a style-first desktop profile for Debian 13 Trixie amd64 based on:

- custom visual-only Labwc 0.20.2 package
- wlroots 0.20.2 fallback
- Noctalia shell + Noctalia Greeter
- greetd
- KDE/Qt applications without installing Plasma as the target DE
- Kitty, Firefox ESR, Dolphin, Kate, Gwenview, Fastfetch, Yazi, btop, MPD/mpDris2 and rmpc

The public profile deliberately excludes HyFlair, CyLab, the tiling layer and workspace overview.

The QA rule used throughout this work is important:

> Treat the VM snapshot as a clean-install savegame. Restore it before each strict regression run. Do not patch a failed VM manually. Fix the repository/installer upstream, pull the fix, restore the clean snapshot, and test again.

The intended regression command is:

```bash
set -o pipefail
./scripts/install-lesbian-stable.sh --apply --build \
  2>&1 | tee "$HOME/lesbian-stable-install.log"
status=${PIPESTATUS[0]}
printf '\nInstaller Exit-Code: %s\n' "$status"
```

Do not reboot after a failed installer run.

## Verified milestone

On 2026-08-27 the installer completed for the first time with:

```text
Installer Exit-Code: 0
```

Verified before reboot:

- `greetd`, `lesbian-labwc`, `noctalia`, `noctalia-greeter`, `rmpc`, `yazi` installed
- `display-manager.service -> /usr/lib/systemd/system/greetd.service`
- `greetd.service` enabled
- Noctalia Greeter lists `Plasma (Wayland)`, `labwc - lesbian singularity x7`, and `labwc`
- `mpd.service`, `mpDris2.service`, `pipewire.service`, and `wireplumber.service` active/running

The first reboot reached the Noctalia Greeter and the system was bootable.

## Changes made and why

### 1. Noctalia repository helper: privilege fallback

`scripts/02-setup-noctalia-repo.sh`

The clean VM exposed that graphical `pkexec` is not always usable during the installer. Root escalation was changed to prefer graphical `pkexec` when available, then fall back to `sudo`, otherwise fail clearly.

Commit:
- `e119e55` — Noctalia sudo fallback

### 2. Yazi: use the official APT repository

`scripts/02-setup-yazi-repo.sh`
`sources/packaging/apt/yazi.list`

Yazi was not available from the expected Debian package set in the clean VM. The installer now configures the official Yazi Debian/Ubuntu stable repository:

```text
deb [signed-by=/usr/share/keyrings/yazi-keyring.gpg] https://yazi-rs.github.io/builds/ stable main
```

The helper also received the same `pkexec -> sudo -> error` privilege fallback.

Commits:
- `51f28f6` — add official Yazi source
- `43fc0e9` — Yazi sudo fallback

### 3. Noctalia runtime installation

`scripts/lesbian-stable-packages.sh`
`scripts/install-lesbian-stable.sh`

The runtime package list was missing the Noctalia shell itself. It was added, and Noctalia + Noctalia Greeter are installed deliberately from `trixie-backports`.

Commits:
- `df994f4` — add Noctalia to portable runtime
- `1079151` — install Noctalia stack from Trixie backports

Important current drift:
- the VM installed `noctalia 5.0.0~beta.9-1+deb13u1`
- `VERSION` still says `Noctalia 5.0.0-beta.8`
- the installer currently asks APT for the current package from `trixie-backports`, not an exact Noctalia version

Decide whether Lesbian Stable should intentionally track the current backport or pin an exact package version. Do not silently leave `VERSION` claiming beta.8 while the installed runtime is beta.9.

### 4. Build dependencies must come from backports too

`scripts/02-install-build-backports.sh`
`scripts/02-install-dependencies.sh`

Clean Debian exposed ABI/version conflicts because runtime libraries had already moved to backports while build `-dev` packages were still being selected from stable.

These five build packages are now deliberately installed from `trixie-backports`:

- `wayland-protocols`
- `libwayland-dev`
- `libdrm-dev`
- `libxkbcommon-dev`
- `libpixman-1-dev`

The helper validates minimum pkg-config versions. The dependency installer separates these packages from normal stable build dependencies and runs the backport helper before the normal build install.

Verified during builds:

- wayland-server 1.25.0
- libdrm 2.4.134
- xkbcommon 1.13.1
- pixman 0.46.4
- wayland-protocols 1.49

Commits:
- `ebb19c2` — build-backports privilege fallback / validation
- `cc6c197` — route build dependencies through backports

The wlroots X11 backend reports `NO` because `xcb-renderutil` is absent. This is not a blocker for the target Wayland compositor; Xwayland is enabled.

### 5. rmpc packaging made self-contained

`sources/scripts/build-rmpc-deb.sh`

The old builder expected a non-existent repository directory `sources/packaging/rmpc/`. That failed after the Labwc package had already built successfully.

The rmpc builder was rewritten to package directly from the pinned verified upstream archive and project license. It now verifies the archive hash, validates expected files and version, generates Debian metadata/changelog, installs the BSD license, normalizes timestamps/modes, and builds with `dpkg-deb --root-owner-group`.

Commit:
- `2f5af42` — make rmpc packaging self-contained

Verified output package:
- `rmpc 0.11.0-1+warehouse13.1`

### 6. Missing Labwc profile templates / stale directory layout

`scripts/deploy-lesbian-stable-config.sh`
`config-template/labwc/{rc.xml,menu.xml,environment,autostart,keybindings.md}`
`.github/workflows/validate.yml`

The deploy script still expected `config-template/lesbian-stable/labwc/`, but the current repository layout uses `config-template/labwc/`.

The missing portable Labwc profile files were added and the deploy script was changed to the real layout. CI syntax/XML/style-boundary checks were updated to use the same layout.

Relevant commits:
- `64ece02` — add portable Labwc rc template
- intermediate commits adding menu/environment/autostart/keybindings
- `d8f3009` — deploy current Labwc template layout
- `a8dd2c1` — validate current Labwc template layout

Do not reintroduce `config-template/lesbian-stable/labwc/`.

### 7. MPD/mpDris2 placeholder bug

`config-template/mpd/mpd.conf`
`config-template/mpDris2/mpDris2.conf`
`scripts/deploy-lesbian-stable-config.sh`

Both music configs used `@@MUSIC@@`, but the renderer only replaces `@@HOME@@`, `@@OUTPUT@@` and `@@WEATHER_LOCATION@@`. Result: `mpd.service` failed during profile deployment.

Both configs now use `@@HOME@@/Musik`. The deploy script also avoids noisy `xdg-mime` calls when `qtpaths` is unavailable.

Commits:
- `1199637` — fix MPD music directory placeholder
- `b05f049` — fix mpDris2 music directory placeholder
- `d04a1b0` — quiet xdg-mime fallback

After this fix both MPD and mpDris2 are active/running. First-start MPD log lines about missing database/state files were non-fatal.

### 8. greetd could not replace an existing SDDM alias

`scripts/07-install-noctalia-greeter.sh`

The old script backed up `/etc/systemd/system/display-manager.service` but did not remove the existing alias before `systemctl enable greetd.service`. On the clean VM the alias still pointed to `sddm.service`, so enabling greetd failed.

The script now records and backs up the current display-manager target, disables the previous manager for future boots without stopping the current graphical session, removes the shared alias, enables greetd, reloads systemd, and verifies both alias and enabled state.

It is generic for SDDM/LightDM/other display managers instead of hardcoding LightDM.

Commit:
- `16a0ed2` — switch display manager alias cleanly to greetd

Verified result:

```text
display-manager.service -> /usr/lib/systemd/system/greetd.service
greetd.service: enabled
```

### 9. Manifest maintenance

`MANIFEST.sha256`

Several changes required manifest updates. There was also an older malformed `.gitignore` manifest line which was corrected during the regression work.

Important manifest commits:
- `4f1574d` — corrected `.gitignore` entry and rmpc builder hash
- `5889a74` — Labwc profile template hashes
- `e1533ca` — MPD profile fix hashes
- `3c65eda` — greetd display-manager switch hash

When changing any tracked file, update `MANIFEST.sha256`; CI runs `sha256sum -c MANIFEST.sha256`.

## Current first-boot findings — OPEN

### A. rEFInd did not appear

This is **not yet an installer regression**.

The successful QA command was:

```bash
./scripts/install-lesbian-stable.sh --apply --build
```

It did **not** include `--refind`. The installer intentionally performs the rEFInd/EFI step only when `--refind` is supplied.

Next action:
- test the dedicated `--refind` path separately on a UEFI VM with `/boot/efi` mounted
- decide whether product UX should keep rEFInd opt-in or whether the desired install flow should include it automatically
- do not call the missing boot theme a bug until that product decision/test is made

### B. Noctalia Greeter works, but login-field position is wrong

The custom Greeter starts correctly, but the login field is not in the intended design position.

Relevant files:
- `config-template/noctalia-greeter/greeter.toml`
- `config-template/greetd/noctalia-greeter.toml`
- greeter wallpaper asset

Investigate the Noctalia Greeter 1.2.1 configuration/schema for layout/positioning. Do not assume the current appearance keys control login-card position.

### C. Noctalia shell theme/settings were not applied

This is the most important current desktop bug.

The Labwc session boots, but Noctalia did **not** come up with the configured Lesbian Stable theme/settings that were copied during deployment.

Relevant deployed inputs:
- `config-template/noctalia/settings.toml`
- `config-template/noctalia/state.toml`
- `config-template/noctalia/wallpaper-vibrant-current.json`
- `config-template/noctalia/palettes/Warehouse-13-Lesbian.json`
- `sources/plugins/lesbian-heart-visualizer/`

The deploy script currently installs:
- `state.toml` and `wallpaper-vibrant-current.json` to `~/.local/state/noctalia/`
- rendered `settings.toml` to `~/.local/state/noctalia/settings.toml`
- palette JSON to `~/.config/noctalia/palettes/`

Do not immediately change random values. First inspect what Noctalia beta.9 actually reads/writes on first launch and whether the config/state paths or schema changed from beta.8. Compare generated runtime files after login against the shipped templates.

This may be related to the beta.8 -> beta.9 runtime drift noted above.

### D. Duplicate Labwc session desktop file

The custom package currently installs both `labwc-lesbian-stable.desktop` and `labwc-warehouse13.desktop` with the same session data.

`noctalia-greeter sessions` currently collapses them to one visible `labwc - lesbian singularity x7`, but the duplicate is unnecessary and should be removed from `sources/scripts/build-lesbian-labwc-deb.sh` after the functional first-boot issues are fixed.

## Greeter config permission

Reading `/var/lib/noctalia-greeter/greeter.toml` as the normal user returns permission denied. That is expected because the file is intentionally owned/restricted for `_greetd`. Use `sudo` when inspecting it; do not loosen permissions just to make QA easier.

## Current session naming

The desired visible session name is `labwc - lesbian singularity x7`. Noctalia Greeter already detects it correctly.

Do not switch the Greeter default to the desktop filename stem; Noctalia Greeter expects the session `Name=` value shown by `noctalia-greeter sessions`.

## Recommended next order

1. Do not disturb the now-working installer/build path while debugging first-login appearance.
2. Inspect Noctalia beta.9 runtime config/state locations and schema after a real login.
3. Fix the Noctalia theme/settings deployment based on those observed files.
4. Fix Greeter login-card position using the actual 1.2.1 supported config.
5. Test rEFInd separately with `--refind` on UEFI.
6. Remove duplicate `labwc-warehouse13.desktop`.
7. Decide and document Noctalia version policy (pin exact package vs follow backports).
8. Re-run the full clean-snapshot regression after each upstream fix.

## Known-good installer state

The installer path from clean Debian through package build, package install, profile deployment and greetd activation is now known-good.

Do not replace it with manual VM edits when debugging the remaining visual problems.
