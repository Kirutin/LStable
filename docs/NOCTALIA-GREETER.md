# Noctalia Greeter

Der Login wird von `greetd` mit dem offiziellen, unveraenderten
`noctalia-greeter` bereitgestellt. Die einzige angebotene Desktop-Sitzung ist
`labwc-lesbian-stable`. Das Theme verwendet die Warehouse-13-Lesbian-Palette,
das eigene Login-Wallpaper, Breeze-Cursor und eine deutsche Tastatur ohne
Tottasten.

Die aktuelle QEMU-VM meldet 1280x800 faelschlich als bevorzugten Modus.
Darum erzwingt die Greeter-Konfiguration hier 1920x1080. Vor dem
Bare-Metal-Abbild werden `width` und `height` unter `[output]` anhand des
wirklich angeschlossenen Monitors angepasst oder entfernt, damit dessen EDID
den bevorzugten Modus bestimmt.

## Installation

Die benoetigten Pakete sind `greetd`, `noctalia-greeter` und
`accountsservice`. Nach deren Installation zeigt ein Trockenlauf alle Ziele:

```bash
scripts/07-install-noctalia-greeter.sh
```

Die systemweite Anwendung erfolgt mit:

```bash
pkexec scripts/07-install-noctalia-greeter.sh --apply
```

Das Skript sichert die vorhandenen greetd-Dateien unter
`/var/backups/warehouse-13-greeter/`, installiert Theme und Wallpaper mit
Zugriff nur fuer `_greetd`, deaktiviert LightDM fuer kommende Starts und
aktiviert greetd. Die laufende grafische Sitzung wird nicht beendet.

## Erster echter Test

Nach einem Neustart muss der Noctalia Greeter erscheinen. Die Anmeldung als
`kiru` muss `labwc-lesbian-stable` starten. Danach pruefen:

```bash
systemctl status greetd --no-pager
journalctl -u greetd -b --no-pager
```

LightDM erst entfernen, wenn dieser echte Login erfolgreich war.

## Rueckfall auf LightDM

Falls der Greeter nicht erscheint, mit `Strg`+`Alt`+`F2` auf eine Textkonsole
wechseln, als `kiru` anmelden und ausfuehren:

```bash
sudo systemctl disable greetd.service
sudo systemctl enable lightdm.service
sudo reboot
```

Die vor dem Wechsel angelegten Konfigurationssicherungen bleiben unter
`/var/backups/warehouse-13-greeter/` erhalten.
