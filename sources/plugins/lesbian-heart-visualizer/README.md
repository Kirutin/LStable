# Lesbian Heart Visualizer

Lokales Noctalia-v5-Desktop-Widget fuer Warehouse-13. Das Widget stellt den
laufenden PipeWire-Ausgang als pink-violettes Herz aus 40 Frequenzbaendern dar.
Das Herz ist waehrend der Wiedergabe sichtbar und blendet nach dem Ausklingen
aus.

Ein unsichtbarer Bar-Widget-Eintrag abonniert Noctalias nativen
PipeWire-Spektrumanalysator und reicht dessen 40 Baender ueber den gemeinsamen
Plugin-Zustand an das Desktop-Widget weiter. Cava, ein eigener Aufnahmeprozess,
eine weitere Desktop-Umgebung oder ein Noctalia-Patch sind nicht erforderlich.

## Lokaler Test

```bash
noctalia plugins lint .
```

Plugin-ID und Widget-Typ:

```text
kiru/lesbian-heart-visualizer
kiru/lesbian-heart-visualizer:spectrum-bridge
kiru/lesbian-heart-visualizer:heart
```
