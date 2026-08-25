# Contributing

Keep the project Debian-native and easy to remove or upgrade. Do not add a
desktop-environment meta-package, automatic `apt autoremove`, private machine
state, browser profiles, secrets or VM-specific device identifiers.

Before proposing a change:

1. run `./scripts/01-preflight.sh`;
2. run the installer without `--apply` and review its plan;
3. run shell, XML and TOML syntax checks;
4. build the local packages when changing Labwc patches;
5. update `MANIFEST.sha256` for every tracked artifact change.

Keep upstream patches separated by responsibility. A new Labwc release must
first compile unmodified, then receive the visual patches one at a time.
