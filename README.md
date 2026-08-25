# Lesbian Stable

Lesbian Stable is a deliberately small, style-first Wayland desktop profile
for Debian 13 (Trixie) on amd64:

- Labwc 0.20.2 with the Lesbian Stable visual patches
- Noctalia and the Noctalia Greeter
- Qt applications without KDE Plasma as a desktop environment
- Kitty, Firefox, Dolphin, Kate, Gwenview, Fastfetch, Yazi, btop and rmpc
- PipeWire, MPD/mpDris2 and the optional Lesbian Heart visualizer
- a matching rEFInd theme, installed only as an explicit EFI step

The project intentionally does not ship HyFlair, CyLab, a tiling layer or a
workspace overview. Debian's normal package manager remains the source of
system packages; the local Labwc/rmpc packages are built from pinned sources.

## Install

The installer is read-only by default:

```bash
./scripts/install-lesbian-stable.sh
```

After reviewing the plan:

```bash
./scripts/install-lesbian-stable.sh --apply --build
```

Use `--apply` without `--build` when the local `.deb` artifacts already exist.
User configuration is backed up before it is replaced. The installer targets
Debian Trixie amd64 and does not run `apt autoremove`.

rEFInd is intentionally separate because it changes the boot path:

```bash
./scripts/install-lesbian-stable.sh --apply --refind
```

Only run that step on the final bare-metal machine in UEFI mode with the ESP
mounted at `/boot/efi`. Existing rEFInd files are backed up first.

## Development checks

```bash
./scripts/01-preflight.sh
./scripts/install-lesbian-stable.sh
shellcheck scripts/*.sh sources/scripts/*.sh
```

The build and configuration details are documented in
[`docs/LESBIAN-STABLE.md`](docs/LESBIAN-STABLE.md).

## Licensing

Project-owned scripts, configuration and documentation are MIT-licensed unless
a file says otherwise. Labwc remains GPL-2.0-only; Noctalia and wlroots keep
their upstream licenses, and rmpc/libsfdo retain their BSD terms. The complete
inventory and redistribution notes are in
[`docs/THIRD-PARTY-LICENSES.md`](docs/THIRD-PARTY-LICENSES.md).
The included wallpapers are Kirutin's project artwork; their scope is
documented separately in [`assets/ARTWORK-LICENSE.md`](assets/ARTWORK-LICENSE.md).

## Project status

The VM path is verified. Hardware-specific EDID, firmware and graphics-driver
behaviour still needs to be checked on each bare-metal target before enabling
the rEFInd step.
