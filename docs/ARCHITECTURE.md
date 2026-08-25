# Architektur – Lesbian Stable

## Schichten

1. **Labwc 0.20.2** verwaltet Fenster, Fokus, Arbeitsflaechen, Menues,
   Rundungen und Transparenz. Die Lesbian-Stable-Patches bleiben auf die
   Optik beschraenkt; es gibt keinen eigenen Tiling-Layer.
2. **wlroots 0.20.2** erhaelt die Clip-Region fuer wirklich runde Client-Inhalte.
3. **Noctalia v5** kommt unveraendert aus dem Debian-Trixie-Repository und
   liefert Bar, Widgets, Launcher, Wallpaper und Farbvorlagen. Der lokale
   **Lesbian Heart Visualizer** erweitert Noctalia ueber dessen oeffentliche
   Plugin-Schnittstelle; er patcht weder Paket noch Programmdateien.
4. **CyLab, HyFlair-Zonen und die Workspace-Overview** sind kein Bestandteil
   des distributablen Lesbian-Stable-Labwc-Pakets. Labwc bleibt der schlanke
   Compositor; Konfiguration erfolgt ueber seine normalen XML-/Theme-Dateien.
6. **MPD** spielt als systemd-Userdienst aus `~/Musik` ueber die Pulse-
   Kompatibilitaet von PipeWire. Dadurch laufen Musik und Noctalias nativer
   Spektrumanalysator ueber denselben Sink-Monitor. **rmpc** ist der
   Terminal-Client; **mpDris2** exportiert Zustand und Metadaten per
   MPRIS an Noctalia und Fastfetch. Der Heart-Visualizer verwendet Noctalias
   nativen PipeWire-Spektrumanalysator ueber ein unsichtbares Plugin-Bridge-
   Widget und benoetigt weder Mikrofonzugriff noch Cava.
7. **Yazi**, Fastfetch und btop sind eigenstaendige Terminalwerkzeuge. Ihre
   Konfigurationen teilen die Warehouse-13-Palette, veraendern aber weder Bash
   noch den Compositor.
8. **Dolphin**, **Kate** und **Discover** laufen als einzelne Qt6/KDE-
   Anwendungen mit Plasma-Integration. Plasma Desktop, KWin und SDDM sind
   ausdruecklich kein Bestandteil; Labwc bleibt die einzige Desktop-Sitzung.
9. **greetd** startet den unveraenderten **Noctalia Greeter** und uebergibt an
   `labwc-lesbian-stable`. Das Login-Theme liegt getrennt unter
   `/var/lib/noctalia-greeter`; LightDM bleibt bis zum bestaetigten echten
   Login lediglich als installierte Rueckfalloption erhalten.

## Patch-Reihenfolge

Labwc:

1. Fenstertransparenz
2. runde Client-Ecken
3. Fokusrahmen fuer Client-Dekorationen
4. mehrfarbige einheitliche Fensterrahmen
5. runde Menues
6. saubere angezeigte Paketversion
7. rundes Arbeitsflaechen-OSD

wlroots:

- Scene-Buffer-Clip-Region fuer runde untere und obere Client-Ecken.

Die von Meson verwendeten Fallback-Quellen `libsfdo` und `libliftoff` liegen
ebenfalls als gepinnte Git-Bundles bei. Dadurch bleibt der Quellbau offline
reproduzierbar, sobald Debians Entwicklungspakete installiert sind.

Noctalia wird nicht gepatcht. Updates laufen getrennt ueber APT und duerfen
CyLabs Labwc-Schnittstellen nicht beeinflussen.

## Nicht implementiert

Compositor-Blur ist noch kein Bestandteil. Fenstertransparenz ist vorhanden.
KDE-Aktivitaeten wurden bewusst nicht nachgebaut.
