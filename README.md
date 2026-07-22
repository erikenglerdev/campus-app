# Campus Köthen App

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](LICENSE)

Monorepo für die **Campus Köthen** App — News, Mensapläne und Kontakte für den Campus Köthen.

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

| Enthalten                                      | Nicht enthalten                               |
| ---------------------------------------------- | --------------------------------------------- |
| News mit dynamischer Kanal-Auswahl             | Nutzerkonten                                  |
| Mensapläne (alle Preisgruppen)                 | Push-Nachrichten                              |
| Kontakte und Kontaktbereiche                   | WebUntis / Stundenplan                        |
| Lokale Einstellungen (Sprache, Theme, Abos)    | Gebäudepläne, Raumbelegung, Indoor-Navigation |
| Offline-/Cache-Verhalten                       | Analytics, Tracking, Crash-Reporting          |
| About, Impressums- und Datenschutz-Platzhalter | Redis, SMTP                                   |
| Deutsch und Englisch                           | Automatisches Deployment                      |

Details: [docs/product/mvp.md](docs/product/mvp.md)

## Architektur

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
                        └──► WebUntis, öffentliche Ansicht (deaktivierbar)
```

Harte Systemgrenzen:

- Flutter spricht **ausschließlich** mit der versionierten Campus API unter `/v1` — niemals direkt mit Strapi oder meine-mensa.de.
- Das Backend liest Strapi **ausschließlich** über dessen REST-API mit einem serverseitigen Read-only-Token — niemals direkt aus Strapi-Tabellen.
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
infrastructure/
  local/                       Lokaler Compose-Stack
  myaioffice-dev/              Dokumentierter DEV-Deployment-Vertrag (kein Deployment)
docs/                          Produkt-, Architektur- und Betriebsdokumentation
.github/workflows/             CI, Image-Publishing, Uptime-Check
```

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
  && flutter analyze && flutter test
```

## Lizenz

**AGPL-3.0-only** — siehe [LICENSE](LICENSE).

`Copyright © 2026 Erik Engler and Jona Sommer`

Drittanbieter-Abhängigkeiten und separat lizenzierte Assets (u. a. die gebündelte
Manrope-Schrift unter SIL OFL 1.1) sind in [NOTICE.md](NOTICE.md) dokumentiert.

## Offene Release-Gates

Diese Punkte sind bewusst **nicht** erledigt und blockieren eine Veröffentlichung:

- [ ] Organisatorische Bestätigung des Betreibers (vorgesehen: Studierendenrat der Hochschule Anhalt — aktuell **nicht** als Betreiber ausgewiesen)
- [ ] Vollständiges Impressum (aktuell bilinguale Platzhalterseite)
- [ ] Vollständige Datenschutzerklärung (aktuell bilinguale Platzhalterseite)
- [ ] Support-Kontaktadresse
- [ ] Finales App-Icon (aktuell neutraler eigener Platzhalter)
- [ ] SMTP für Strapi-Einladungen und Passwort-Reset
- [ ] Offsite-Backups für beide Datenbanken und Strapi-Uploads
- [ ] PROD-Server und Domains
- [ ] Freigabe realer Kontaktdaten und ggf. Personenfotos (aktuell nur als Demo markierte Seeds)

## Beitragen

Siehe [CLAUDE.md](CLAUDE.md) für die verbindlichen Entwicklungsregeln
(TypeScript strict, TDD, keine Secrets, keine Hochschulassets).
