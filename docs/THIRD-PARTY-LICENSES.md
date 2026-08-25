# Lizenzübersicht

Dieses Repository enthält eigene Konfigurationen, Skripte, Patches und
Dokumentation. Diese eigenen Bestandteile stehen unter der MIT-Lizenz in
[`LICENSE`](../LICENSE), sofern eine Datei keinen spezifischeren Hinweis trägt.
Die folgenden Komponenten bleiben unter ihren jeweiligen Upstream-Lizenzen:

| Bestandteil | Verwendung | Lizenz | Nachweis |
| --- | --- | --- | --- |
| Labwc 0.20.2 | gepinnte Quelle und unser Style-Patch | GPL-2.0-only | [`Upstream`](https://github.com/labwc/labwc), `sources/vendor/labwc-0.20.2.bundle`, [`licenses/GPL-2.0-only.txt`](../licenses/GPL-2.0-only.txt) |
| wlroots 0.20.2 | Build-Abhängigkeit für Labwc | MIT | [`Upstream`](https://github.com/swaywm/wlroots), `sources/vendor/wlroots-0.20.2.bundle` |
| Noctalia v5.0.0-beta.8 | Laufzeit/Greeter-Abhängigkeit | MIT | [`Upstream`](https://github.com/noctalia-dev/noctalia), `sources/vendor/noctalia-v5.0.0-beta.8.tar.gz`, [`licenses/NOCTALIA-MIT.txt`](../licenses/NOCTALIA-MIT.txt) |
| Noctalia Greeter | Login-Greeter-Abhängigkeit | MIT | [Upstream-Lizenz](https://github.com/noctalia-dev/noctalia-greeter/blob/main/LICENSE), [`licenses/NOCTALIA-GREETER-MIT.txt`](../licenses/NOCTALIA-GREETER-MIT.txt) |
| libliftoff | Build-Abhängigkeit | MIT | `sources/vendor/libliftoff-9114b1e.bundle`, [`licenses/MIT-LIBLIFTOFF.txt`](../licenses/MIT-LIBLIFTOFF.txt) |
| libsfdo | Build-Abhängigkeit | BSD-3-Clause | `sources/vendor/libsfdo-v0.1.4.bundle`, [`licenses/BSD-3-Clause-LIBSFDO.txt`](../licenses/BSD-3-Clause-LIBSFDO.txt) |
| rmpc v0.11.0 | optionaler Musikplayer | BSD-3-Clause | [`Upstream`](https://github.com/mierak/rmpc), `sources/vendor/rmpc-v0.11.0-x86_64-unknown-linux-gnu.tar.gz`, [`licenses/BSD-3-Clause-RMPC.txt`](../licenses/BSD-3-Clause-RMPC.txt) |
| Lesbian Heart Visualizer | eigenes Noctalia-Plugin | GPL-2.0-only | `sources/plugins/lesbian-heart-visualizer/plugin.toml` |
| rEFInd icons | eigenes Icon-Set | MIT | [`sources/refind/rEFInd-lesbian-singularity/icons/LICENSE`](../sources/refind/rEFInd-lesbian-singularity/icons/LICENSE) |

Die vollständigen Noctalia-Drittlizenzen liegen zusätzlich im Noctalia-Archiv
unter `third_party/` (u. a. fzy, Luau, Material Color Utilities und Wuffs).
Sie werden nicht als eigenständige Bibliotheken in diesem Repository gebaut.

Die Debian-Pakete, Qt-Anwendungen, Firefox, PipeWire und weitere Systempakete
werden nicht in diesem Repository ausgeliefert; sie behalten ihre Debian- bzw.
Upstream-Lizenzen.

## Artwork und Marken

Die Wallpaper in `assets/` und der rEFInd-Hintergrund wurden für Kirutin mit
ChatGPT erstellt. Kirutin hat die Weiterverteilung als Bestandteil dieses
Projekts freigegeben; sie sind jedoch kein Softwarebestandteil und werden nicht
automatisch durch die MIT-Lizenz des Codes abgedeckt. Die Zuordnung ist in
[`assets/ARTWORK-LICENSE.md`](../assets/ARTWORK-LICENSE.md) dokumentiert.

Die rEFInd-Icons stehen separat unter MIT; die Lizenzdatei liegt direkt im
Icon-Verzeichnis. Upstream-rEFInd selbst und eventuell daraus übernommene
Marken/Logos behalten ihre jeweiligen Rechte.

Bei Änderungen an Labwc-Quelltext oder daraus abgeleiteten Binärpaketen müssen
die GPL-2.0-only-Hinweise sowie der korrespondierende Quelltext und die
Build-Skripte verfügbar bleiben. Die Änderungen in diesem Projekt sind über
`sources/packaging/patches/labwc-lesbian/` nachvollziehbar.
