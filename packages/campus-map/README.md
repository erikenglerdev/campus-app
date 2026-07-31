<!-- Campus Köthen App · AGPL-3.0-only · Copyright © 2026 Erik Engler and Jona Loreen Sommer -->

# @campus/map

Kanonischer Kartenkatalog, SVG-Validator und Generator der gebündelten Flutter-Kartenassets.

> ⚠️ **Der enthaltene Plan ist vollständig fiktiv.** Gebäude, Etage und alle 30 Räume sind
> Demonstrationsdaten. Es wird kein realer Grundriss abgebildet.

## Inhalt

```text
buildings/demo-north/level2.svg   kanonische Geometriequelle
catalog/campus-map.catalog.json   kanonische strukturierte Quelle
src/
  svg-reader.mjs                  strikter Allowlist-Parser für den genutzten XML-Ausschnitt
  validate.mjs                    Querprüfung Katalog ↔ SVG
  generate.mjs                    erzeugt die App-Assets (rein, deterministisch)
  cli.mjs                         validate | generate | check
```

Erzeugt wird nach `apps/mobile/assets/maps/`: `map_catalog.json` und das bereinigte Etagen-SVG.

## Kommandos

```bash
pnpm --filter @campus/map validate   # Katalog gegen das SVG prüfen
pnpm --filter @campus/map generate   # App-Assets neu schreiben
pnpm --filter @campus/map check      # prüfen und Drift melden (CI-Gate)
pnpm --filter @campus/map test       # 47 Tests
```

## Warum dependency-frei

Wie `packages/openapi`: Die Kette von der kanonischen Zeichnung bis zum Asset im App-Bundle soll
vollständig überprüfbar bleiben, ohne dass ein XML-Parser eines Drittanbieters dazwischen steht.
Der Reader ist deshalb eine **Allowlist** — DOCTYPE, CDATA und alles andere, was er nicht
ausdrücklich versteht, wird abgelehnt statt bestmöglich geraten. Damit existiert die
Entity-Expansion-Angriffsfläche gar nicht erst.

## Warum das generierte SVG anders aussieht

Zwei Gründe, beide durch Tests festgehalten:

- Die kanonische Zeichnung enthält **deutsche** Überschriften, Legende und Beschriftungen. Im
  generierten Asset überleben nur sprachneutrale Raumnummern; alles andere rendert Flutter aus der
  l10n.
- `flutter_svg` unterstützt **keine** `<style>`-Blöcke und verwirft die gesamte Stylesheet. Die
  CSS-Klassenregeln werden deshalb in Präsentationsattribute aufgelöst; `<marker>` und `marker-*`
  entfallen, weil der Renderer sie ignoriert.

Vollständige Beschreibung inklusive CMS-Sync und Rechteprozess:
[`docs/campus-map.md`](../../docs/campus-map.md).
