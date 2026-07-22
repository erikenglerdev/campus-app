# NOTICE

## Campus Köthen App

```text
Campus Köthen App
Copyright © 2026 Erik Engler and Jona Sommer

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

| | |
| --- | --- |
| Pfad im Repository | `apps/mobile/assets/fonts/` |
| Upstream | <https://github.com/sharanda/manrope> · <https://fonts.google.com/specimen/Manrope> |
| Designer | Mikhail Sharanda |
| Copyright | `Copyright 2018 The Manrope Project Authors (https://github.com/sharanda/manrope)` |
| Lizenz | **SIL Open Font License, Version 1.1** (`OFL-1.1`) |
| Lizenztext | [`apps/mobile/assets/fonts/OFL.txt`](apps/mobile/assets/fonts/OFL.txt) |

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

Die Abhängigkeiten werden **nicht** in dieses Repository einvendort. Maßgeblich und
maschinenlesbar sind:

| Ökosystem | Quelle der Lizenzangaben |
| --- | --- |
| npm / pnpm | `pnpm-lock.yaml`, `pnpm licenses list` |
| Flutter / Dart | `apps/mobile/pubspec.lock`, `flutter pub deps` |
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
