<!-- Campus Köthen App · AGPL-3.0-only · Copyright © 2026 Erik Engler and Jona Loreen Sommer -->

# Abhängigkeits-Lizenzen — Moodle-Integration & quellenübergreifender Kalender

Dieses Dokument belegt die Lizenz-Verträglichkeit **jeder** Abhängigkeit, die für die
Moodle-Integration und den quellenübergreifenden Kalender neu hinzukommt. Das Projekt steht unter
`AGPL-3.0-only`; jede direkte **und** transitive Abhängigkeit muss damit vereinbar sein.

## 1. Neu hinzugefügte Abhängigkeiten

**Keine.** Weder die Moodle-Integration noch der quellenübergreifende Kalender führen eine neue
Abhängigkeit ein.

Der Kalender nutzte zwischenzeitlich `table_calendar` (Apache-2.0) samt dessen transitiver
`simple_gesture_detector` für das Monatsraster. Beide sind mit dem Wegfall des Monatsrasters
**entfernt** worden: Tag-, Wochen- und Listenansicht bestehen aus gewöhnlichen Flutter-Widgets.
Die Bewertung entfällt damit, sie ist nur noch Historie.

## 2. Bereits vorhandene, von Moodle wiederverwendete Abhängigkeiten

Die Moodle-Integration nutzt ausschließlich Abhängigkeiten, die bereits für Mail/Noten geprüft und
in [`../../NOTICE.md`](../../NOTICE.md) dokumentiert sind:

| Paket                    | Lizenz         | Nutzung in der Moodle-Integration                                       |
| ------------------------ | -------------- | ----------------------------------------------------------------------- |
| `dio`                    | `MIT`          | HTTPS-Transport (nur `moodle.hs-anhalt.de`), Datei-Download             |
| `flutter_secure_storage` | `BSD-3-Clause` | Ablage des Web-Service-Tokens im Keychain/Keystore                      |
| `hive_ce`                | `Apache-2.0`   | verschlüsselter lokaler Cache (256-Bit-Schlüssel in Secure Storage)     |
| `pdfx`                   | `MIT`          | PDF-Vorschau heruntergeladener Materialien (geteilter DocumentViewer)   |
| `share_plus`             | `BSD-3-Clause` | „Teilen/Speichern" als sichere Alternative zur In-App-Vorschau          |
| `html`                   | `BSD-3-Clause` | Reduktion von Moodle-HTML (Kurs-/Modulbeschreibungen) auf sicheren Text |
| `url_launcher`           | `BSD-3-Clause` | Öffnen externer Moodle-Links **ohne** Token (nur `https`)               |

## 3. Prüfvorgehen

- Lizenztyp je Paket aus der `LICENSE`-Datei im pub-cache-Verzeichnis **und** aus den pub.dev-
  Metadaten gelesen.
- Exakt eingebundene Versionen stammen aus [`../../apps/mobile/pubspec.lock`](../../apps/mobile/pubspec.lock).
- Transitiver Abhängigkeitsbaum über `flutter pub deps` geprüft.
- Eingebettete Schriften/JS/Assets, sowie `Commons-Clause`/`BSL`/`SSPL`/`PolyForm`/`NC`/`ND`
  ausgeschlossen.

## 4. Ergebnis (Moodle/Kalender)

Es kommt für Moodle und Kalender keine Abhängigkeit hinzu; die wiederverwendeten sind mit
`AGPL-3.0-only` **verträglich**. Das Lizenz-Gate für diese Arbeit ist erfüllt.

---

# Abhängigkeits-Lizenzen — öffentliche Google-Kalender (ICS)

Für die serverseitige ICS-Synchronisation öffentlicher Google-Kalender kommt genau **eine** neue
direkte Abhängigkeit im Backend hinzu; sie hat **keine** Laufzeit-Abhängigkeiten (Transitive =
leer). Kein Flutter-Paket wird neu eingeführt (die App nutzt das bereits vorhandene `url_launcher`).

| Paket     | Version | Lizenz    | Quelle                                                              | Zweck                                                                                                                                             | Transitive Prüfung                                                                                                                                                                           | AGPL-3.0-Bewertung                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| --------- | ------- | --------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ical.js` | 2.2.1   | `MPL-2.0` | `LICENSE` im Paket · <https://github.com/kewisch/ical.js> (Mozilla) | RFC-5545-Parser (VTIMEZONE, RRULE/RDATE/EXDATE, RECURRENCE-ID, Ganztag, DST) — nur Parsing des bereits geladenen Textes, **kein** Netzwerkzugriff | `dependencies: {}` in der veröffentlichten `package.json` und im installierten `node_modules/.pnpm/ical.js@2.2.1/…/package.json` verifiziert → **keine** transitiven Laufzeit-Abhängigkeiten | **Kompatibel.** MPL-2.0 ist dateiweise Copyleft und über die „Secondary License"-Klausel (§ 3.3) mit der AGPL-3.0 des Projekts vereinbar — dieselbe Bewertung wie für `enough_mail`/`enough_convert` (siehe [`../../NOTICE.md`](../../NOTICE.md) §4). Der Quellcode wird **nicht** einvendort und **nicht** verändert; er wird ausschließlich als unveränderte npm-Abhängigkeit eingebunden. Eigene TypeScript-Typen (`dist/types/module.d.ts`) — kein `@types`-Paket nötig. |

Prüfvorgehen: `npm view ical.js@2.2.1 license dependencies types` und die installierte
`package.json` gelesen (`license: MPL-2.0`, `dependencies: {}`, `types: dist/types/module.d.ts`);
eine `LICENSE`-Datei liegt dem Paket bei. **Es wird bewusst KEINE URL-Fetch-Funktion des Parsers
verwendet** — der Netzwerkzugriff bleibt ausschließlich im abgesicherten `GooglePublicIcsClient`;
dem Parser wird nur der bereits vollständig geladene, größenbegrenzte Text übergeben.

Da die MPL-2.0 dateiweise Copyleft ist und der Backend-Container den kompilierten Code enthält, wird
der Hinweis auf den **unveränderten** Quellcode in [`../../NOTICE.md`](../../NOTICE.md) geführt
(öffentlich und unverändert unter <https://www.npmjs.com/package/ical.js>; die exakt eingebundene
Version steht in `apps/backend/pnpm-lock.yaml`).

**Ergebnis:** Das Lizenz-Gate für die öffentliche-Kalender-Integration ist erfüllt.

## Lageplan

| Paket         | Version   | Lizenz | Bewertung                                                                                                                                               |
| ------------- | --------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `flutter_svg` | `^2.0.10` | MIT    | Permissiv, mit AGPL-3.0-only vereinbar. Wird ausschließlich mit lokalen, im Repository validierten Assets verwendet — nie mit SVG aus einer Netzquelle. |

`packages/campus-map` selbst ist **dependency-frei**: Validator, SVG-Reader und Generator kommen
ohne Laufzeitabhängigkeit aus, damit die Kette von der kanonischen Zeichnung bis zum gebündelten
App-Asset vollständig überprüfbar bleibt.
