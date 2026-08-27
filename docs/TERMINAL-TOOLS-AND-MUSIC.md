# Terminal-Werkzeuge und Musik

## Fastfetch

Die Konfiguration liegt unter `~/.config/fastfetch/config.jsonc`. Sie verwendet
das Warehouse-13-Bild und zeigt bei laufender Musik den MPRIS-Player sowie den
aktuellen Titel. Fastfetch wird bewusst nicht automatisch in `.bashrc` gestartet.

## Yazi

`yazi` startet den Terminal-Dateimanager. Das Theme verwendet dieselbe Palette
wie Noctalia, btop und rmpc. Textdateien werden mit Kate geoeffnet; die Aktion
`In Dolphin zeigen` markiert die aktuelle Datei in Dolphin.

Installierte Vorschauhelfer sind FFmpeg, 7zip, jq, Poppler, fd, fzf, ripgrep,
zoxide und wl-clipboard. Die optionale Bash-Funktion `y`, die beim Beenden das
Terminalverzeichnis wechselt, wird nicht ungefragt in `.bashrc` eingetragen.

## Musikarchitektur

```text
/home/kiru/Musik -> MPD -> PipeWire
                         -> rmpc
                         -> mpDris2 -> MPRIS -> Noctalia/Fastfetch
```

MPD und mpDris2 laufen als aktivierte systemd-Userdienste. Die wichtigsten
Befehle sind:

```bash
rmpc
rmpc update
rmpc addyt 'https://www.youtube.com/watch?v=...'
rmpc searchyt 'Interpret Titel'
systemctl --user status mpd mpDris2
```

Die Audio-Basis besteht aus PipeWire, WirePlumber, pipewire-pulse und rtkit.
`alsa-utils` und `pulseaudio-utils` liefern die Diagnosewerkzeuge. Der
Ausgang wird absichtlich nicht auf eine VM-Geraete-ID fest verdrahtet, damit
WirePlumber auf dem spaeteren Bare-Metal-System die echte Soundkarte waehlt.

```bash
systemctl --user status pipewire wireplumber pipewire-pulse
wpctl status
pactl get-default-sink
```

rmpc verwendet sein Cache-Verzeichnis unter `~/.cache/rmpc`; YouTube-Downloads
landen nicht unkontrolliert im Musikordner. Das Theme bietet Queue, Album-Art,
Lyrics, Tabs und Fortschrittsanzeige. yt-dlp und FFmpeg stammen aus Debian.
