<!-- Campus Köthen App · AGPL-3.0-only · Copyright © 2026 Erik Engler and Jona Sommer -->

# Abhängigkeits-Lizenzen — Moodle-Integration & quellenübergreifender Kalender

Dieses Dokument belegt die Lizenz-Verträglichkeit **jeder** Abhängigkeit, die für die
Moodle-Integration und den quellenübergreifenden Kalender neu hinzukommt. Das Projekt steht unter
`AGPL-3.0-only`; jede direkte **und** transitive Abhängigkeit muss damit vereinbar sein.

## 1. Neu hinzugefügte Abhängigkeiten

Für den quellenübergreifenden Kalender wird genau **eine** direkte Abhängigkeit neu eingeführt
(`table_calendar`), die genau **eine** transitive Abhängigkeit nachzieht
(`simple_gesture_detector`). Die Moodle-Integration führt **keine** neue Abhängigkeit ein.

| Paket                     | Version | Lizenz       | Quelle                                                                     | Verwendungszweck                                              | Kompatibilitätsbewertung                                                                                                    |
| ------------------------- | ------- | ------------ | -------------------------------------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| `table_calendar`          | 3.2.0   | `Apache-2.0` | `LICENSE` im Paket · <https://github.com/aleksanderwozniak/table_calendar> | Monatsraster (Kalenderansicht) des Kalender-Tabs             | **Kompatibel.** Apache-2.0 ist einseitig mit (A)GPLv3 verträglich; darf in ein AGPL-3.0-Werk aufgenommen werden.           |
| `simple_gesture_detector` | 0.2.1   | `Apache-2.0` | `LICENSE` im Paket · <https://github.com/aleksanderwozniak/simple_gesture_detector> | Wisch-Gesten für `table_calendar` (transitiv)        | **Kompatibel.** Apache-2.0, siehe oben. Einzige transitive Neu-Abhängigkeit von `table_calendar`.                          |

Beide Pakete stammen vom selben Autor, enthalten je eine unveränderte `Apache License, Version 2.0`
als `LICENSE`-Datei, ziehen keine weiteren Nicht-Flutter-Pakete nach und bündeln **keine** Schriften,
kein eingebettetes JavaScript und keine sonstigen Assets mit abweichender Lizenz. Es liegt **keine**
`Commons-Clause`-, `BSL`-, `SSPL`-, `PolyForm`-, `NC`- oder `ND`-Klausel vor.

## 2. Bereits vorhandene, von Moodle wiederverwendete Abhängigkeiten

Die Moodle-Integration nutzt ausschließlich Abhängigkeiten, die bereits für Mail/Noten geprüft und
in [`../../NOTICE.md`](../../NOTICE.md) dokumentiert sind:

| Paket                    | Lizenz         | Nutzung in der Moodle-Integration                                        |
| ------------------------ | -------------- | ------------------------------------------------------------------------ |
| `dio`                    | `MIT`          | HTTPS-Transport (nur `moodle.hs-anhalt.de`), Datei-Download              |
| `flutter_secure_storage` | `BSD-3-Clause` | Ablage des Web-Service-Tokens im Keychain/Keystore                       |
| `hive_ce`                | `Apache-2.0`   | verschlüsselter lokaler Cache (256-Bit-Schlüssel in Secure Storage)      |
| `pdfx`                   | `MIT`          | PDF-Vorschau heruntergeladener Materialien (geteilter DocumentViewer)    |
| `share_plus`             | `BSD-3-Clause` | „Teilen/Speichern" als sichere Alternative zur In-App-Vorschau           |
| `html`                   | `BSD-3-Clause` | Reduktion von Moodle-HTML (Kurs-/Modulbeschreibungen) auf sicheren Text  |
| `url_launcher`           | `BSD-3-Clause` | Öffnen externer Moodle-Links **ohne** Token (nur `https`)               |

## 3. Prüfvorgehen

- Lizenztyp je Paket aus der `LICENSE`-Datei im pub-cache-Verzeichnis **und** aus den pub.dev-
  Metadaten gelesen.
- Exakt eingebundene Versionen stammen aus [`../../apps/mobile/pubspec.lock`](../../apps/mobile/pubspec.lock).
- Transitiver Abhängigkeitsbaum über `flutter pub deps` geprüft: `table_calendar` zieht nur
  `simple_gesture_detector` (Flutter/Dart) nach.
- Eingebettete Schriften/JS/Assets, sowie `Commons-Clause`/`BSL`/`SSPL`/`PolyForm`/`NC`/`ND`
  ausgeschlossen.

## 4. Ergebnis

Alle neuen direkten und transitiven Abhängigkeiten sind mit `AGPL-3.0-only` **verträglich**. Das
Lizenz-Gate für diese Arbeit ist erfüllt.
