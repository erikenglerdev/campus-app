# Architektur

Campus Köthen App · `AGPL-3.0-only` · Copyright © 2026 Erik Engler and Jona Sommer

---

## 1. Überblick

```text
      Redaktion / Herausgeber
                │ HTTPS (Admin-Panel)
                ▼
        ┌───────────────────┐        ┌──────────────────────┐
        │  Strapi 5 (CMS)   │───────►│  campus_cms_<env>    │
        │  apps/cms         │        │  Rolle: campus_cms   │
        └───────────────────┘        └──────────────────────┘
                │
                │ REST /api/*  ·  serverseitiges Read-only-Token
                │ (nur Backend → Strapi, nie App → Strapi)
                ▼
        ┌───────────────────┐        ┌──────────────────────┐
   ┌───►│  Campus API       │───────►│  campus_app_<env>    │
   │    │  apps/backend     │        │  Rolle: campus_app   │
   │    │  NestJS + Prisma  │        └──────────────────────┘
   │    └───────────────────┘                   ▲
   │ HTTPS /v1                                  │ Prisma
   │                                 ┌──────────────────────┐
┌──┴─────────────┐                   │  Campus Worker       │
│ Flutter        │                   │  apps/backend        │
│ apps/mobile    │                   │  dist/worker.js      │
│ iOS / Android  │                   └──────────────────────┘
└────────────────┘                              │ HTTPS, alle 2 h
                                                ▼
                                     https://meine-mensa.de/api/food_plans
```

## 2. Harte Systemgrenzen

Verstöße gegen diese Regeln sind Blocker, keine Stilfragen.

| # | Grenze |
| --- | --- |
| G1 | Flutter spricht **ausschließlich** mit der Campus API unter `/v1`. Kein direkter Zugriff auf Strapi oder `meine-mensa.de`. |
| G2 | Das Backend liest Strapi **ausschließlich** über dessen REST-API mit einem serverseitigen Read-only-Token. Kein Zugriff auf Strapi-Tabellen. |
| G3 | Redaktionelle Inhalte liegen in Strapi. Importierte Mensadaten und Sync-Zustände liegen in `campus_app_<env>`. |
| G4 | CMS und operative Daten nutzen **getrennte Datenbanken und getrennte Rollen**. Keine Rolle hat Zugriff auf beide. |
| G5 | Die Strapi Public Role erhält **keine** allgemeinen öffentlichen Leserechte. Die Campus API nutzt ein eigenes minimales Read-only-Token. |
| G6 | Die Strapi-Adresse ist nie eine Quellcode-Konstante — ausschließlich `STRAPI_BASE_URL`. |
| G7 | Umgebungsunterschiede entstehen **nur** durch Environment/Secrets, nie durch Quellcode oder Branches. |
| G8 | Öffentliche DTOs leaken keine Strapi-Internas (`data`, `attributes`, `documentId`, `meta.pagination` der Quelle). |
| G9 | PostgreSQL wird nie öffentlich gebunden. |

## 3. Komponenten

### 3.1 `apps/cms` — Strapi 5 Community

- TypeScript, Draft & Publish für News, offizielle i18n-Plugin-Funktionen für `de`/`en`.
- Content-Types: `news-channel`, `news-article`, `author`, `contact-area`, `contact-person`.
- Uploads im persistenten Volume unter `/opt/app/public/uploads`.
- Rollen: Redaktion (ohne Publish), Herausgeber (mit Publish), Super-Admin separat.
  Für den Start genügt ein manuell angelegter Super-Admin; SMTP folgt später.
- Health: `GET /_health`.

### 3.2 `apps/backend` — Campus API + Worker

Eine Codebasis, zwei Einstiegspunkte:

| Einstiegspunkt | Start | Aufgabe |
| --- | --- | --- |
| API | `node dist/main.js` | HTTP-Server auf `0.0.0.0:3000` |
| Worker | `node dist/worker.js` | Zeitgesteuerte Mensa-Synchronisierung |

Module:

```text
src/
  config/            typisierte, validierte Konfiguration (Zod)
  common/            Locale-Auflösung, Fehlerfilter, Logging, Pagination
  modules/
    health/          /health/live, /health/ready
    strapi/          gekapselter StrapiClient (Timeout, Retry, typisierte Fehler)
    news/            /v1/news/*
    contacts/        /v1/contact-areas/*
    canteen/         /v1/canteens/*, Sync-Service, meine-mensa-Client + Zod-Schema
  main.ts            API-Bootstrap
  worker.ts          Worker-Bootstrap
```

Der Worker läuft als **eigener Container** aus demselben Image. Er teilt sich die Datenbank mit der
API, aber nicht den Prozess — ein Sync-Fehler kann die API nicht blockieren.

### 3.3 `apps/mobile` — Flutter

Feature-first, Riverpod für State, go_router für Navigation, dio als HTTP-Client:

```text
lib/
  core/
    theme/           typisierte Design-Tokens, Light- und Dark-Theme
    network/         Dio-Client, API-Konfiguration via --dart-define
    cache/           hive_ce-Repositories, Stale-Metadaten
    prefs/           SharedPreferences für kleine Skalare
  l10n/              ARB-Dateien de/en (gen_l10n)
  features/
    news/  canteen/  contacts/  settings/  about/  legal/
```

`API_BASE_URL` wird über `--dart-define` gesetzt. Die Strapi-URL gelangt **nie** in die App.

### 3.4 `packages/openapi`

Der aus den NestJS-DTOs erzeugte, versionierte OpenAPI-Vertrag. Er ist das gemeinsame Artefakt
zwischen Backend und Flutter und wird in CI gegen den Code geprüft.

## 4. Datenhaltung

### 4.1 Trennung

| Datenbank | Rolle | Inhalt | Zugriff durch |
| --- | --- | --- | --- |
| `campus_cms_<env>` | `campus_cms` | Strapi-Tabellen, redaktionelle Inhalte | nur Strapi |
| `campus_app_<env>` | `campus_app` | `Canteen`, `Meal`, `IngredientDefinition`, `SyncRun` | nur Campus API + Worker |

Redaktionelle Inhalte werden **nicht** in die operative Datenbank gespiegelt. Die API liest sie bei
Bedarf über Strapi.

### 4.2 Operatives Schema (Prisma)

```text
Canteen                 slug (unique), sourceLocationId (unique), displayName, campusLabel, active
Meal                    sourcePlanId (unique) ← Upsert-Schlüssel, canteenId, date, counterId,
                        isSprint, name, subtitle, extras[], ingredientCodes[],
                        prices (Decimal, alle Gruppen), sourceUpdatedAt, importedAt
IngredientDefinition    code (PK), labelDe, labelEn?, kind (ingredient | marker)
SyncRun                 source, startedAt, finishedAt, status, recordsReceived,
                        recordsUpserted, errorMessage
```

Geldwerte sind `Decimal`, niemals `float`. `Meal.imageUrl` existiert **nicht** — die Bild-URL der
Quelle wird bewusst nicht persistiert.

## 5. Locale-Vertrag der Campus API

Priorität der Auflösung:

1. Query-Parameter `locale` (`de` | `en`) — höchste Priorität.
2. Header `Accept-Language`, sofern kein `locale`-Parameter gesetzt ist.
3. Standard `de`.

Ein **nicht unterstützter expliziter** `locale`-Parameter wird mit `400` abgelehnt. Ein nicht
unterstützter `Accept-Language`-Wert fällt still auf `de` zurück.

Jede inhaltliche Antwort trägt:

```json
{
  "meta": {
    "requestedLocale": "en",
    "resolvedLocale": "en",
    "translationFallback": false
  }
}
```

`translationFallback` ist `true`, sobald mindestens ein ausgeliefertes Feld aus der Fallback-Locale
stammt. Externe Mensa-Gerichtsnamen werden **nie** übersetzt; sie sind bei `locale=en` immer
Fallback und werden entsprechend markiert.

## 6. Resilienz der Mensa-Synchronisierung

```text
Worker-Tick (CANTEEN_SYNC_CRON, Standard "0 */2 * * *")
   │
   ├─ SyncRun anlegen (status = running)
   ├─ HTTP GET mit Timeout und Retry mit exponentiellem Backoff
   │     └─ Fehler ⇒ SyncRun(failed) · KEIN Löschen bestehender Daten · Abbruch
   ├─ Antwort gegen Zod-Schema validieren
   │     └─ ungültig ⇒ SyncRun(failed) · KEIN Löschen · Abbruch
   ├─ location_id jedes Eintrags gegen die angefragte Mensa prüfen
   │     └─ Mismatch ⇒ Eintrag verwerfen und zählen
   ├─ leere data-Liste ⇒ SyncRun(empty) · KEIN Löschen · Abbruch
   └─ Upsert über sourcePlanId
         └─ Aufräumen NUR innerhalb des erfolgreich synchronisierten Zeitraums
            und NUR nach erfolgreicher, nicht-leerer Antwort
```

`lastSuccessfulSyncAt` ist der jüngste `SyncRun` mit `status = success`. `dataStale` ist `true`,
wenn dieser Zeitpunkt älter als `CANTEEN_STALE_AFTER_MINUTES` ist.

## 7. Betrieb

### 7.1 Container

| Image | Port | Health | User |
| --- | --- | --- | --- |
| `ghcr.io/erikenglerdev/campus-app-cms` | `0.0.0.0:1337` | `GET /_health` | non-root |
| `ghcr.io/erikenglerdev/campus-app-backend` | `0.0.0.0:3000` | `GET /health/live`, `GET /health/ready` | non-root |
| `postgres:16-alpine` (offiziell, gepinnt) | intern | `pg_isready` | — |

Der Worker nutzt dasselbe Backend-Image mit abweichendem Startkommando. Zielplattform der
veröffentlichten Images: **ausschließlich `linux/amd64`**.

### 7.2 Health-Semantik

- `/health/live` prüft **nur** den Prozess. Es darf nie durch eine Abhängigkeit fehlschlagen,
  sonst würde ein Datenbankausfall unnötige Container-Neustarts auslösen.
- `/health/ready` prüft kontrolliert und **mit Timeout** die Datenbank und die erreichbare
  Strapi-Instanz.

### 7.3 Umgebungswechsel

```dotenv
# DEV
STRAPI_BASE_URL=https://cms-dev.<domain>
DATABASE_URL=postgresql://campus_app:<secret>@postgres:5432/campus_app_dev

# PROD
STRAPI_BASE_URL=https://cms.<domain>
DATABASE_URL=postgresql://campus_app:<secret>@postgres:5432/campus_app_prod
```

Kein manueller URL-Austausch in mehreren Dateien, kein umgebungsspezifischer Code.

## 8. Bewusste Nicht-Entscheidungen

| Thema | Status |
| --- | --- |
| Redis | nicht im MVP — kein Caching-Layer nötig, Datenmengen sind klein |
| SMTP | später — Strapi-Admins werden zunächst manuell angelegt |
| Sentry / Analytics | dauerhaft ausgeschlossen im MVP |
| Automatisches Deployment | ausgeschlossen — Images werden gebaut, Deployment bleibt manuell |
| Offsite-Backups | offenes Release-Gate, **nicht** eingerichtet |
| WebUntis, Raumpläne, Indoor-Navigation | außerhalb des MVP; Architektur bleibt erweiterbar |
