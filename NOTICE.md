# NOTICE

## Campus Köthen App

```text
Campus Köthen App
Copyright © 2026 Erik Engler and Jona Loreen Sommer

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU Affero General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>.
```

SPDX-Bezeichner des Projektcodes: `AGPL-3.0-only`. Vollständiger Lizenztext: [LICENSE](LICENSE).

---

## 1. Unabhängigkeitshinweis / Independence notice

**Deutsch** — Campus Köthen ist eine unabhängige, inoffizielle Campus-App. Sie wird weder von der
Hochschule Anhalt entwickelt oder betrieben noch von ihr offiziell unterstützt. Die Nennung der
Hochschule und ihrer Einrichtungen dient ausschließlich der sachlichen Zuordnung öffentlich
zugänglicher Informationen.

**English** — Campus Köthen is an independent, unofficial campus app. It is neither developed nor
operated by Hochschule Anhalt, nor is it officially endorsed by the university. The university and
its institutions are named solely for the factual attribution of publicly available information.

Dieses Repository enthält **keine** Logos, Wappen, Markenassets oder Designsystem-Kopien der
Hochschule Anhalt oder des Studentenwerks Halle.

---

## 2. Gebündelte Assets mit eigener Lizenz

### 2.1 Manrope (Schriftart)

|                    |                                                                                     |
| ------------------ | ----------------------------------------------------------------------------------- |
| Pfad im Repository | `apps/mobile/assets/fonts/`                                                         |
| Upstream           | <https://github.com/sharanda/manrope> · <https://fonts.google.com/specimen/Manrope> |
| Designer           | Mikhail Sharanda                                                                    |
| Copyright          | `Copyright 2018 The Manrope Project Authors (https://github.com/sharanda/manrope)`  |
| Lizenz             | **SIL Open Font License, Version 1.1** (`OFL-1.1`)                                  |
| Lizenztext         | [`apps/mobile/assets/fonts/OFL.txt`](apps/mobile/assets/fonts/OFL.txt)              |

Die Schrift wird **lokal gebündelt** und zur Laufzeit **nicht** von Google Fonts oder einem anderen
CDN geladen. Es findet dadurch keine Verbindung zu Drittanbietern beim Start der App statt.

Die OFL-1.1 ist mit der AGPL-3.0 kompatibel; die Schrift bleibt unter ihrer eigenen Lizenz und wird
**nicht** unter das Projekt-Copyright gestellt. Der Copyright-Header der Schriftdateien wird nicht
verändert.

### 2.2 App-Icons und Platzhalter-Grafiken

Die App-Icons und Platzhalter-Illustrationen sind **Eigenentwicklungen** dieses Projekts
(abstraktes Campus-/Verbindungs-Motiv) und stehen unter `AGPL-3.0-only` wie der übrige Projektcode.

Sie sind ausdrücklich **neutrale Platzhalter**: kein Hochschullogo, kein Hochschulgebäude, keine
visuelle Logoimitation. Das finale App-Icon ist ein offenes Release-Gate.

---

### 2.3 Demo-Lageplan (Kartenassets)

|                    |                                                                      |
| ------------------ | -------------------------------------------------------------------- |
| Pfad im Repository | `packages/campus-map/buildings/` · `apps/mobile/assets/maps/`        |
| Urheberschaft      | vollständig selbst erstellt für dieses Projekt                       |
| Lizenz             | `AGPL-3.0-only`, wie das übrige Projekt                              |
| Inhalt             | **frei erfundenes** Demogebäude mit 30 fiktiven Räumen (B.201–B.230) |

Der Plan bildet **keinen** realen Grundriss ab. Es wurden keine fremden Gebäudepläne, Flucht- oder
Rettungspläne, Logos oder Markenassets verwendet oder nachgezeichnet. Die Assets werden mit der App
gebündelt und zur Laufzeit nie nachgeladen.

Reale Gebäudepläne dürfen erst nach geklärter Herkunft sowie Bearbeitungs- und
Veröffentlichungsberechtigung aufgenommen werden — siehe
[`docs/campus-map.md`](docs/campus-map.md).

## 3. Datenquellen

### 3.1 meine-mensa.de

Die Mensapläne stammen aus der öffentlich erreichbaren Schnittstelle
`https://meine-mensa.de/api/food_plans` (Studentenwerk Halle).

- Die Daten werden **inhaltlich unverändert** übernommen und der Quelle zugeordnet.
- Gerichtsnamen, Zutaten- und Markerbezeichnungen der Quelle liegen nur auf Deutsch vor und werden
  **nicht maschinell übersetzt**, sondern transparent als Fallback gekennzeichnet.
- `food.image_url` wird **weder gespeichert noch ausgeliefert**; es werden keine Mensabilder
  verwendet.
- Die Abrufrate ist auf alle zwei Stunden begrenzt.
- Tests laufen ausschließlich gegen gespeicherte, anonymisierte Fixtures.

Eine abschließende Nutzungsfreigabe durch den Betreiber der Quelle ist ein offenes Release-Gate
(siehe [README.md](README.md#offene-release-gates)).

### 3.2 Redaktionelle Inhalte

Redaktionelle Beiträge sind Eigentexte oder eigene Zusammenfassungen **mit Quellenlink**. Fremde
Volltexte und fremde Bilder werden nicht übernommen. Es werden ausschließlich eigene oder
nachweislich freigegebene Bilder veröffentlicht.

---

## 4. Software-Abhängigkeiten

Dieses Projekt verwendet Open-Source-Abhängigkeiten aus den Ökosystemen npm (Strapi, NestJS,
Prisma) und pub.dev (Flutter, Riverpod, go_router, dio, hive_ce), die jeweils unter ihren eigenen
Lizenzen stehen — überwiegend MIT, Apache-2.0 und BSD-3-Clause.

Der Lageplan nutzt zusätzlich:

| Paket (pub.dev) | Zweck                                            | Lizenz |
| --------------- | ------------------------------------------------ | ------ |
| `flutter_svg`   | Rendern des gebündelten, generierten Etagenplans | `MIT`  |

Es wird ausschließlich mit lokalen, validierten Assets verwendet; niemals mit SVG aus einer
Netzquelle.

Der Client für die studentische E-Mail nutzt zusätzlich:

| Paket (pub.dev)          | Zweck                                          | Lizenz         |
| ------------------------ | ---------------------------------------------- | -------------- |
| `enough_mail`            | IMAP-/SMTP-/MIME-Client                        | `MPL-2.0`      |
| `enough_convert`         | Zeichensatz-Dekodierung (transitiv)            | `MPL-2.0`      |
| `flutter_secure_storage` | Geräte-Schlüsselspeicher für Zugangsdaten      | `BSD-3-Clause` |
| `share_plus`             | Anhänge über das OS-Teilen-Menü teilen         | `BSD-3-Clause` |
| `pdfx`                   | PDF-Anhänge in-App anzeigen (nativer Renderer) | `MIT`          |
| `html`                   | HIS-QIS-HTML parsen (Notenspiegel)             | `BSD-3-Clause` |
| `dio_cookie_manager`     | Cookie-Handling für den QIS-Abruf (dio)        | `MIT`          |
| `cookie_jar`             | In-Memory-Cookie-Jar für den QIS-Abruf         | `MIT`          |
| `meta`                   | Annotationen (`@immutable` u. a.)              | `BSD-3-Clause` |

Die Moodle-Integration nutzt ausschließlich bereits vorhandene Abhängigkeiten (`dio`,
`flutter_secure_storage`, `hive_ce`, `pdfx`, `share_plus`, `html`, `url_launcher`) und führt keine
weiteren ein. Der quellenübergreifende Kalender ebenfalls nicht: Tag-, Wochen- und Listenansicht
bestehen aus gewöhnlichen Flutter-Widgets. Eine ausführliche Bewertung steht in
[`docs/legal/dependency-licenses.md`](docs/legal/dependency-licenses.md).

`enough_mail` und `enough_convert` stehen unter der **Mozilla Public License 2.0**. Ihr Quellcode
wird **nicht** in dieses Repository einvendort und **nicht** verändert; er wird ausschließlich als
unveränderte pub.dev-Abhängigkeit eingebunden. Die MPL-2.0 ist auf Dateiebene copyleft und über
ihre „Secondary License“-Klausel (§ 3.3) mit der AGPL-3.0 des Projekts vereinbar.

Da die App in ausgelieferter Form (APK/IPA) den kompilierten Code dieser Pakete enthält, verlangt
MPL-2.0 § 3.2(b), Empfänger auf den **unveränderten Quellcode** hinzuweisen. Dieser ist öffentlich
und unverändert verfügbar unter <https://pub.dev/packages/enough_mail> bzw.
<https://pub.dev/packages/enough_convert>; die exakt eingebundene Version steht in
`apps/mobile/pubspec.lock`. Zusätzlich zeigt der Flutter-Client den vollständigen MPL-Lizenztext
zur Laufzeit über den `showLicensePage`-Dialog im About-Screen an.

Das **Backend** nutzt für den RFC-5545-Parser der öffentlichen Google-Kalender zusätzlich:

| Paket (npm) | Zweck                                                                        | Lizenz    |
| ----------- | ---------------------------------------------------------------------------- | --------- |
| `ical.js`   | ICS-/iCalendar-Parser (Mozilla), reines Parsing des bereits geladenen Textes | `MPL-2.0` |

`ical.js` (Version in `apps/backend/pnpm-lock.yaml`) steht ebenfalls unter der **Mozilla Public
License 2.0** und hat **keine** Laufzeit-Abhängigkeiten. Der Quellcode wird nicht einvendort und
nicht verändert; er wird als unveränderte npm-Abhängigkeit eingebunden. Der unveränderte Quellcode
ist öffentlich unter <https://www.npmjs.com/package/ical.js> verfügbar. Netzwerkfunktionen des
Pakets werden bewusst nicht verwendet — der Feed-Abruf bleibt im abgesicherten Backend-Client.
Bewertung: [`docs/legal/dependency-licenses.md`](docs/legal/dependency-licenses.md).

Die Abhängigkeiten werden **nicht** in dieses Repository einvendort. Maßgeblich und
maschinenlesbar sind:

| Ökosystem        | Quelle der Lizenzangaben                          |
| ---------------- | ------------------------------------------------- |
| npm / pnpm       | `pnpm-lock.yaml`, `pnpm licenses list`            |
| Flutter / Dart   | `apps/mobile/pubspec.lock`, `flutter pub deps`    |
| Container-Images | SBOM-Artefakte aus `.github/workflows/images.yml` |

Der Flutter-Client zeigt die Lizenzen seiner Dart-Abhängigkeiten zur Laufzeit über den
standardmäßigen `showLicensePage`-Dialog im About-Screen an.

Erzeugter Code (Strapi-Typen, Prisma-Client, `freezed`/`json_serializable`, `gen_l10n`) wird nicht
mit einem projektfremden Copyright-Header versehen und nicht als Eigenwerk umdeklariert.

---

## 5. Marken

„Hochschule Anhalt“, „Studentenwerk Halle“ und weitere genannte Namen sind Bezeichnungen der
jeweiligen Einrichtungen. Sie werden ausschließlich sachlich zur Zuordnung öffentlich zugänglicher
Informationen genannt. Es besteht keine Verbindung, Partnerschaft oder Unterstützung.
