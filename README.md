# Campus Köthen App

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](LICENSE)

Monorepo für die **Campus Köthen** App — News, Kalender, Mensapläne, Kontakte sowie direkt
angebundene persönliche Dienste (Studenten-E-Mail, Notenspiegel, Moodle) für den Campus Köthen.

---

## ⚠️ Unabhängigkeitshinweis / Independence notice

> **Deutsch**
>
> Campus Köthen ist eine unabhängige, inoffizielle Campus-App. Sie wird weder von der Hochschule Anhalt entwickelt oder betrieben noch von ihr offiziell unterstützt. Die Nennung der Hochschule und ihrer Einrichtungen dient ausschließlich der sachlichen Zuordnung öffentlich zugänglicher Informationen.

> **English**
>
> Campus Köthen is an independent, unofficial campus app. It is neither developed nor operated by Hochschule Anhalt, nor is it officially endorsed by the university. The university and its institutions are named solely for the factual attribution of publicly available information.

Dieses Projekt verwendet **keine** Logos, Wappen, Markenassets oder Designsysteme der Hochschule Anhalt.

---

## Status

**MVP in Entwicklung.** Es gibt noch kein öffentliches Deployment. Siehe [Offene Release-Gates](#offene-release-gates).

## Umfang des MVP

| Enthalten                                              | Nicht enthalten                                 |
| ------------------------------------------------------ | ----------------------------------------------- |
| News als endloser Inline-Feed, Kanäle frei wählbar     | Nutzerkonten für die App selbst                 |
| Quellenübergreifender Kalender (Tag/Woche/Liste)       | Push-Nachrichten                                |
| Gruppenstundenplan (WebUntis, serverseitig schaltbar)  | Persönlicher WebUntis-Login                     |
| Öffentliche Google-Kalender (öffentlicher ICS-Feed)    | Reale Gebäudepläne und Grundrisse               |
| Mensapläne (Trait-/Allergenfilter, eine Preisgruppe)   | Analytics, Tracking, Crash-Reporting            |
| Kontakte und Kontaktbereiche                           | Redis, SMTP                                     |
| Studenten-E-Mail (IMAP/SMTP, direkt vom Gerät)         | Automatisches Deployment                        |
| Notenspiegel HIS-QIS (direkt vom Gerät)                | Globale Volltextsuche                           |
| Moodle: Kurse, Materialien, Aufgaben, Ankündigungen    | Schreibzugriffe auf Moodle                      |
| Lokale Aufgabenliste (rein auf dem Gerät)              | Serverseitige Synchronisierung der Aufgaben     |
| Anträge & Feedback (direkt an das Gremiensystem)       | Serverseitige Ablage von Anträgen               |
| Lageplan: Demo-Etagenplan, Räume antippbar und suchbar | Indoor-Navigation, Wegberechnung, Live-Position |
| Räume mit Kontaktbezug und Deep-Link in den Plan       | Raumbelegung und Buchung                        |
| Lokale Einstellungen (Sprache, Theme, Abos)            | Mehrere Mail- oder Moodle-Konten                |
| Offline-/Cache-Verhalten                               |                                                 |
| About, Impressums- und Datenschutz-Platzhalter         |                                                 |
| Deutsch und Englisch                                   |                                                 |

Details: [docs/product/mvp.md](docs/product/mvp.md)

## Architektur

Die App hat **zwei streng getrennte Datenpfade**. Welcher Pfad gilt, entscheidet allein die
Sensibilität der Daten — nicht die Bequemlichkeit.

**Pfad 1 — öffentliche und redaktionelle Daten: immer über das Backend**

```text
Redaktion ──► Strapi 5 (CMS) ──► campus_cms_* (PostgreSQL 16)
                   │
                   │ REST, serverseitiges Read-only-Token
                   ▼
Flutter ──/v1──► Campus API (NestJS) ──► campus_app_* (PostgreSQL 16)
                                              ▲
                   Campus Worker ─────────────┘
                        │
                        ├──► meine-mensa.de (alle 2 Stunden)
                        ├──► WebUntis, öffentliche Ansicht (WEBUNTIS_ENABLED)
                        └──► calendar.google.com, öffentlicher ICS-Feed
                             (PUBLIC_CALENDAR_ENABLED)
```

**Pfad 2 — persönliche, authentifizierte Dienste: direkt vom Gerät, bewusst am Backend vorbei**

```text
                 ┌──► mail.hs-anhalt.de          IMAPS 993 / SMTP 587 + STARTTLS
Flutter ─────────┼──► service.ssc.hs-anhalt.de   HIS-QIS-Notenspiegel
                 └──► moodle.hs-anhalt.de        Moodle-Webservice (nur lesend)
```

Damit erhalten weder Campus API, Strapi noch Worker jemals Zugangsdaten oder persönliche Inhalte.
Zugangsdaten liegen ausschließlich im Keychain/Keystore, zwischengespeicherte Inhalte nur
verschlüsselt auf dem Gerät. Dies sind **genau drei** ausdrücklich beschlossene Ausnahmen — keine
allgemeine Erlaubnis für beliebige Direktzugriffe (siehe [CLAUDE.md](CLAUDE.md) §2).

Harte Systemgrenzen:

- Flutter spricht für alle öffentlichen und redaktionellen Daten **ausschließlich** mit der versionierten Campus API unter `/v1` — niemals direkt mit Strapi, meine-mensa.de, WebUntis oder dem Google-ICS-Feed.
- Das Backend liest Strapi **ausschließlich** über dessen REST-API mit einem serverseitigen Read-only-Token — niemals direkt aus Strapi-Tabellen.
- Für Mail, Noten und Moodle gibt es **keinen** Backend-Proxy, **keine** serverseitige Speicherung und **keinen** Analytics-/Logging-Umweg.
- Der Kalender führt Stundenplan, öffentliche Kalender und Moodle-Deadlines **ausschließlich lokal auf dem Gerät** zusammen.
- CMS und operative Daten nutzen **getrennte Datenbanken und Rollen**.
- Umgebungsunterschiede entstehen ausschließlich durch Environment/Secrets, nicht durch Quellcode.

Details: [docs/architecture.md](docs/architecture.md)

## Repository-Struktur

```text
apps/
  cms/                         Strapi 5 Community (TypeScript)
  backend/                     NestJS Campus API + Prisma + Worker
  mobile/                      Flutter (iOS/Android)
packages/
  openapi/                     Veröffentlichter API-Vertrag (OpenAPI 3.1)
  campus-map/                  Kanonischer Kartenkatalog, Validator, Asset-Generator
infrastructure/
  local/                       Lokaler Compose-Stack
  myaioffice-dev/              Dokumentierter DEV-Deployment-Vertrag (kein Deployment)
docs/                          Produkt-, Architektur- und Betriebsdokumentation
.github/workflows/             CI, Image-Publishing, Uptime-Check
```

## Dokumentation

| Dokument                                                          | Inhalt                                                     |
| ----------------------------------------------------------------- | ---------------------------------------------------------- |
| [product/mvp.md](docs/product/mvp.md)                             | Umfang, fachliche Anforderungen, Akzeptanzkriterien        |
| [architecture.md](docs/architecture.md)                           | Komponenten, Systemgrenzen, Datenhaltung, Betrieb          |
| [api.md](docs/api.md)                                             | Verbindlicher Vertrag der Campus API                       |
| [data-sources.md](docs/data-sources.md)                           | Alle Fremdquellen mit verifizierten Eigenheiten            |
| [public-calendars.md](docs/public-calendars.md)                   | Öffentliche Google-Kalender über den öffentlichen ICS-Feed |
| [student-mail.md](docs/student-mail.md)                           | Studenten-E-Mail-Client (IMAP/SMTP, direkt vom Gerät)      |
| [grades.md](docs/grades.md)                                       | HIS-QIS-Notenspiegel (direkt vom Gerät)                    |
| [moodle.md](docs/moodle.md)                                       | Moodle-Integration und quellenübergreifender Kalender      |
| [requests.md](docs/requests.md)                                   | Anträge und Feedback ans Gremiensystem (direkt vom Gerät)  |
| [local-development.md](docs/local-development.md)                 | Lokaler Stack, Schritt für Schritt                         |
| [content-editor-guide.md](docs/content-editor-guide.md)           | Handbuch für die Redaktion in Strapi                       |
| [legal/dependency-licenses.md](docs/legal/dependency-licenses.md) | Lizenzbewertung der Abhängigkeiten                         |

## Voraussetzungen

| Werkzeug         | Version                                    |
| ---------------- | ------------------------------------------ |
| Node.js          | 22.x (Strapi 5.50 unterstützt `>=20 <=26`) |
| pnpm             | >= 10 (hier: 11.15.1, via Corepack)        |
| Docker + Compose | Docker 29.x, Compose v5                    |
| Flutter          | stable channel                             |
| PostgreSQL       | 16 (über Compose)                          |

## Schnellstart (lokal)

```bash
corepack enable
pnpm install --frozen-lockfile

# Lokale Datenbanken starten (CMS-DB + App-DB, getrennte Rollen)
cp infrastructure/local/.env.example infrastructure/local/.env
pnpm compose:local:up

# Backend
cp apps/backend/.env.example apps/backend/.env
pnpm --filter @campus/backend prisma:migrate:dev
pnpm --filter @campus/backend start:dev      # http://localhost:3000/docs

# CMS
cp apps/cms/.env.example apps/cms/.env
pnpm --filter @campus/cms develop            # http://localhost:1337/admin

# Flutter
cd apps/mobile
flutter pub get
flutter gen-l10n
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

Vollständige Anleitung: [docs/local-development.md](docs/local-development.md)

## Qualitätsgates

```bash
pnpm format:check
pnpm lint
pnpm typecheck
pnpm test
pnpm --filter @campus/cms build

cd apps/mobile
flutter gen-l10n && dart format --output=none --set-exit-if-changed . \
  && flutter analyze --fatal-infos --fatal-warnings && flutter test
```

Die CI führt zusätzlich aus: Prisma-Migrationen gegen ein echtes PostgreSQL, den Abgleich von
[`packages/openapi/openapi.json`](packages/openapi/openapi.json) gegen den Code, einen Secret-Scan,
ein Dependency-Audit sowie Greps gegen hartkodierte UI-Texte und gegen jede Verwendung von
`food.image_url`. Siehe [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

## Lizenz

**AGPL-3.0-only** — siehe [LICENSE](LICENSE).

`Copyright © 2026 Erik Engler and Jona Loreen Sommer`

Drittanbieter-Abhängigkeiten und separat lizenzierte Assets (u. a. die gebündelte
Manrope-Schrift unter SIL OFL 1.1) sind in [NOTICE.md](NOTICE.md) dokumentiert.

## Offene Release-Gates

Diese Punkte sind bewusst **nicht** erledigt und blockieren eine Veröffentlichung. Sie dürfen
**nicht** durch erfundene Werte ersetzt werden.

**Organisatorisch und rechtlich**

- [ ] Organisatorische Bestätigung des Betreibers (vorgesehen: Studierendenrat der Hochschule Anhalt — aktuell **nicht** als Betreiber ausgewiesen)
- [ ] Vollständiges Impressum (aktuell bilinguale Platzhalterseite)
- [ ] Vollständige Datenschutzerklärung (aktuell bilinguale Platzhalterseite)
- [ ] Support-Kontaktadresse
- [ ] Freigabe realer Kontaktdaten und ggf. Personenfotos (aktuell nur als Demo markierte Seeds)

**Freigabe der Datenquellen**

- [ ] Nutzungsfreigabe der Mensa-Datenquelle durch den Betreiber
- [ ] Nutzungsfreigabe der WebUntis-Stundenplanquelle: Erlaubnis zur automatisierten Nutzung der internen View-API, akzeptable Abrufrate, Stabilitätszusage bzw. offizielle API, gewünschte Quellenangabe, zulässige Speicherung von Lehrpersonennamen — bis dahin bleibt `WEBUNTIS_ENABLED=false`
- [ ] Abstimmung mit der Hochschule Anhalt über die automatisierte Nutzung des HIS-QIS-Prüfungsportals
- [ ] Veröffentlichungsrechte je öffentlichem Google-Kalender: Zustimmung des Inhabers, zulässiger Quellenhinweis, ob Beschreibung und Ort gezeigt werden dürfen, Verhalten bei Entzug
- [ ] **Reale Gebäudepläne**: Herkunft, Bearbeitungs- und Veröffentlichungsrecht, Ausschluss sicherheitsrelevanter Pläne, Personenbezug und Pflegeprozess klären — bis dahin bleibt es beim fiktiven Demo-Plan ([docs/campus-map.md](docs/campus-map.md))

**Technisch und betrieblich**

- [ ] Finales App-Icon (aktuell neutraler eigener Platzhalter)
- [ ] SMTP für Strapi-Einladungen und Passwort-Reset
- [ ] Offsite-Backups für beide Datenbanken und Strapi-Uploads
- [ ] PROD-Server und Domains
- [ ] App-Switcher-Vorschau des Notenbildschirms: bewusst offene Datenschutzentscheidung, siehe [docs/grades.md](docs/grades.md)

## Beitragen

Siehe [CLAUDE.md](CLAUDE.md) für die verbindlichen Entwicklungsregeln
(TypeScript strict, TDD, keine Secrets, keine Hochschulassets).
