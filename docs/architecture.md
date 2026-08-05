# Architektur

Campus Köthen App · `AGPL-3.0-only` · Copyright © 2026 Erik Engler and Jona Loreen Sommer

---

## 1. Überblick

Die App nutzt **zwei streng getrennte Datenpfade**. Welcher Pfad gilt, entscheidet allein die
Sensibilität der Daten.

### 1.1 Pfad 1 — öffentliche und redaktionelle Daten über das Backend

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
└────────────────┘                              │ HTTPS
                                                ├──► meine-mensa.de/api/food_plans
                                                │      alle 2 h
                                                ├──► hsa.webuntis.com  (öffentliche View-API)
                                                │      WEBUNTIS_ENABLED, Default false
                                                └──► calendar.google.com  (öffentlicher ICS-Feed)
                                                       PUBLIC_CALENDAR_ENABLED, Default false
```

### 1.2 Pfad 2 — persönliche, authentifizierte Dienste direkt vom Gerät

```text
┌────────────────┐
│ Flutter        │──HTTPS/IMAPS/SMTP──► mail.hs-anhalt.de         E-Mail (IMAP 993, SMTP 587)
│ apps/mobile    │──HTTPS─────────────► service.ssc.hs-anhalt.de  HIS-QIS-Notenspiegel
│                │──HTTPS─────────────► moodle.hs-anhalt.de       Moodle-Webservice (lesend)
└────────────────┘
        │
        └── Zugangsdaten/Token: Keychain / Keystore · Inhalte: verschlüsselter lokaler Cache
```

Diese drei Dienste laufen **bewusst am Backend vorbei**, damit weder Campus API noch Strapi noch
Worker jemals Zugangsdaten oder persönliche Inhalte erhalten. Es sind **genau drei** ausdrücklich
beschlossene Ausnahmen — jede weitere muss in [`../CLAUDE.md`](../CLAUDE.md) §2 ergänzt werden.

Die Zusammenführung von Stundenplan (Pfad 1), öffentlichen Kalendern (Pfad 1) und Moodle-Deadlines
(Pfad 2) im Kalender-Tab geschieht **ausschließlich lokal auf dem Gerät**. Kein Server sieht die
kombinierte Ansicht.

## 2. Harte Systemgrenzen

Verstöße gegen diese Regeln sind Blocker, keine Stilfragen.

| #   | Grenze                                                                                                                                                                                      |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| G1  | Für öffentliche und redaktionelle Daten spricht Flutter **ausschließlich** mit der Campus API unter `/v1`. Kein direkter Zugriff auf Strapi, `meine-mensa.de`, WebUntis oder den ICS-Feed.  |
| G2  | Das Backend liest Strapi **ausschließlich** über dessen REST-API mit einem serverseitigen Read-only-Token. Kein Zugriff auf Strapi-Tabellen.                                                |
| G3  | Redaktionelle Inhalte liegen in Strapi. Importierte Mensa-, Stundenplan- und Kalenderdaten sowie Sync-Zustände liegen in `campus_app_<env>`.                                                |
| G4  | CMS und operative Daten nutzen **getrennte Datenbanken und getrennte Rollen**. Keine Rolle hat Zugriff auf beide.                                                                           |
| G5  | Die Strapi Public Role erhält **keine** allgemeinen öffentlichen Leserechte. Die Campus API nutzt ein eigenes minimales Read-only-Token.                                                    |
| G6  | Die Strapi-Adresse ist nie eine Quellcode-Konstante — ausschließlich `STRAPI_BASE_URL`.                                                                                                     |
| G7  | Umgebungsunterschiede entstehen **nur** durch Environment/Secrets, nie durch Quellcode oder Branches.                                                                                       |
| G8  | Öffentliche DTOs leaken keine Strapi-Internas (`data`, `attributes`, `documentId`, `meta.pagination` der Quelle) und keine Fremd-IDs (WebUntis-IDs, `location_id`, Google-Kalender-ID).     |
| G9  | PostgreSQL wird nie öffentlich gebunden.                                                                                                                                                    |
| G10 | Persönliche Dienste laufen **direkt** vom Gerät zum offiziellen Anbieter: Mail, HIS-QIS, Moodle. **Kein** Backend-Proxy, **keine** serverseitige Speicherung, **kein** Logging-Umweg.       |
| G11 | Für die Direktdienste gilt: nur HTTPS bzw. implizites TLS, feste Host-Allowlist, Redirects auf fremde Hosts werden abgelehnt, Zertifikatsprüfung nie deaktiviert, kein Certificate-Pinning. |
| G12 | Zugangsdaten und Token liegen **ausschließlich** im Keychain/Keystore, persönliche Inhalte nur **verschlüsselt** lokal. Nie in `SharedPreferences` oder einer unverschlüsselten Box.        |
| G13 | Quellenübergreifende Zusammenführung im Kalender geschieht **ausschließlich lokal** in Flutter. Kein Server sieht die kombinierte Ansicht.                                                  |

## 3. Komponenten

### 3.1 `apps/cms` — Strapi 5 Community

- TypeScript, Draft & Publish für News, offizielle i18n-Plugin-Funktionen für `de`/`en`.
- Content-Types: `news-channel`, `news-article`, `author`, `contact-area`, `contact-person`,
  `public-calendar`, `room`.
- `room` ist technische Referenzdatenhaltung: katalogverwaltete Felder gehören
  `packages/campus-map` und sind serverseitig gegen normale Bearbeitungswege geschützt,
  redaktionelle Felder und Kontaktrelationen bleiben editierbar
  ([campus-map.md](campus-map.md)).
- Slugs sind **nicht** lokalisiert und unique — das ist ein eigenes CI-Gate, damit der stabile
  Bezeichner nicht pro Locale auseinanderläuft.
- Uploads im persistenten Volume unter `/opt/app/public/uploads`.
- Rollen: Redaktion (ohne Publish), Herausgeber (mit Publish), Super-Admin separat.
  Für den Start genügt ein manuell angelegter Super-Admin; SMTP folgt später.
- Health: `GET /_health`.

### 3.2 `apps/backend` — Campus API + Worker

Eine Codebasis, zwei Einstiegspunkte:

| Einstiegspunkt | Start                 | Aufgabe                                                       |
| -------------- | --------------------- | ------------------------------------------------------------- |
| API            | `node dist/main.js`   | HTTP-Server auf `0.0.0.0:3000`                                |
| Worker         | `node dist/worker.js` | Zeitgesteuerte Synchronisierung: Mensa, Stundenplan, Kalender |

Module:

```text
src/
  config/            typisierte, validierte Konfiguration (Zod), einmalig beim Boot geprüft
  common/            Locale-Auflösung, Fehlerfilter, JSON-Logging, Pagination,
                     Query-Validierung, Content-Block-Sanitizer
  modules/
    health/          /health/live, /health/ready
    strapi/          gekapselter StrapiClient (Timeout, Retry, typisierte Fehler)
    news/            /v1/news/*
    contacts/        /v1/contact-areas/*
    canteen/         /v1/canteens/*, Sync-Service, meine-mensa-Client + Zod-Schema
    timetable/       /v1/timetable/*, Sync-Service, WebUntis-Client + Zod-Schema
    public-calendar/ /v1/calendars/*, Katalog- und Event-Sync, ICS-Client + RFC-5545-Parser,
                     Google-Freigabelink-Validierung
    rooms/           /v1/rooms/*, Raumkatalog aus Strapi, RoomReference für Kontakte
  cli/               administrative Kommandos: OpenAPI erzeugen, Mensen seeden,
                     Mensa- und Stundenplan-Sync manuell auslösen
  main.ts            API-Bootstrap
  worker.ts          Worker-Bootstrap
```

Der Worker läuft als **eigener Container** aus demselben Image. Er teilt sich die Datenbank mit der
API, aber nicht den Prozess — ein Sync-Fehler kann die API nicht blockieren. Jeder Job hat einen
eigenen Overlap-Guard; Mensa, Stundenplan und Kalender sind unabhängig voneinander schaltbar.

### 3.3 `apps/mobile` — Flutter

Feature-first, Riverpod für State, go_router für Navigation, dio als HTTP-Client:

```text
lib/
  core/
    theme/           typisierte Design-Tokens, Light- und Dark-Theme, Kontrastprüfung
    network/         Dio-Client, API-Konfiguration via --dart-define, typisierte Fehler
    cache/           hive_ce-Repositories, Stale-Metadaten, verschlüsselte Box
    prefs/           SharedPreferences für kleine Skalare
    documents/       geteilter Dokument-Viewer (Bild, PDF, Text) + OS-Teilen
    links/           SafeLinkLauncher (nur https/mailto/tel)
    locale/          Locale-Modus und Formatierung
  l10n/              ARB-Dateien de/en (gen_l10n)
  features/
    news/  canteen/  contacts/  settings/  about/  legal/    Pfad 1, über die Campus API
    timetable/                                               Pfad 1, serverseitig schaltbar
    campusmap/                                               Pfad 1 (Namen) + lokales Asset (Geometrie)
    calendar/                                                lokale Zusammenführung + öffentliche Kalender
    mail/  grades/  moodle/                                  Pfad 2, direkt vom Gerät
    todos/                                                   rein lokal, ohne Netz
    requests/                                                Pfad 2, direkt an das Gremiensystem
    more/                                                    Hub für alles, was nicht angeheftet ist
```

Navigation: **vier frei wählbare Module plus ein festes „Mehr"**, jedes mit eigenem
Navigationsstack. Voreingestellt sind **News · Kalender · Mensa · E-Mail · Mehr**; die ersten vier
sind in den Einstellungen austauschbar und per Drag-and-drop sortierbar.

Woraus diese Navigation besteht, entscheidet **ein** typisierter Modulkatalog
(`lib/app/app_modules.dart`): Storage-ID, Route, voller und kurzer Titel, Icons, Kategorie,
Sortierung und ob ein Modul anheftbar ist. Bottom Navigation, Navigationseinstellungen,
Onboarding, die Mehr-Ansicht und die Reparatur ungültiger gespeicherter Konfigurationen lesen
alle denselben Katalog — getrennt gepflegte Listen würden genau so lange übereinstimmen, bis
jemand eine davon vergisst.

Die Mehr-Ansicht wird daraus abgeleitet: Was angeheftet ist, erscheint dort **nicht** zusätzlich;
alles andere steht unter seiner kanonischen Kategorie (**Studium**, **Campus**, **App**).
Einstellungen und „Über die App" sind nicht anheftbar und stehen immer unter **App**. Gespeichert
werden ausschließlich die vier stabilen Modul-IDs in ihrer Reihenfolge; unbekannte IDs, Duplikate
oder eine falsche Anzahl werden beim Lesen repariert, sodass keine Konfiguration ein Modul
unerreichbar machen kann.

`API_BASE_URL` wird über `--dart-define` gesetzt. Die Strapi-URL gelangt **nie** in die App.

Die Direktdienste sind jeweils hinter einem Port gekapselt (`MailGateway`, `GradesGateway`,
`MoodleRepository`). UI und Riverpod-Controller kennen **keine** `enough_mail`-, Dio-, Cookie-
oder HTML-Typen — das hält die Fremdbibliothek austauschbar und die Tests frei von echten
Netzaufrufen.

### 3.4 `packages/campus-map`

Kanonischer Kartenkatalog, SVG-Validator und Generator der gebündelten Flutter-Kartenassets.
Dependency-frei wie `packages/openapi`. Die Ausgabe ist deterministisch und wird committet; ein
CI-Gate erkennt Drift zwischen Quelle und generiertem Asset. Details:
[campus-map.md](campus-map.md).

### 3.5 `packages/openapi`

Der aus den NestJS-DTOs erzeugte, versionierte OpenAPI-Vertrag. Er ist das gemeinsame Artefakt
zwischen Backend und Flutter und wird in CI gegen den Code geprüft.

### 3.6 Direktintegrationen (Pfad 2)

Drei geräteseitige Integrationen ohne jede Backend-Beteiligung. Jede hat ein eigenes Dokument mit
Bedrohungsmodell, Sicherheitszusagen und manueller Testcheckliste.

| Dienst         | Ziel                       | Transport                                  | Umfang                                                                  | Doku                               |
| -------------- | -------------------------- | ------------------------------------------ | ----------------------------------------------------------------------- | ---------------------------------- |
| Studenten-Mail | `mail.hs-anhalt.de`        | IMAPS 993, SMTP 587 mit Pflicht-STARTTLS   | lesen, suchen, antworten, senden; Ordner wechseln; Anhänge anzeigen     | [student-mail.md](student-mail.md) |
| Notenspiegel   | `service.ssc.hs-anhalt.de` | HTTPS, HTML-Parsing (keine offizielle API) | Notenspiegel lesen; 24-Stunden-Regel                                    | [grades.md](grades.md)             |
| Moodle         | `moodle.hs-anhalt.de`      | HTTPS, Moodle-Webservice (REST)            | Kurse, Materialien, Aufgaben, Ankündigungen, Deadlines — **nur lesend** | [moodle.md](moodle.md)             |

Gemeinsame, nicht verhandelbare Zusagen (G10–G12):

- Feste Host-Allowlist, vor **jedem** Request geprüft. Ein Redirect auf einen anderen Host oder auf
  Klartext wird abgebrochen — ein Token oder Cookie kann so nie an einen fremden Host gelangen.
- Zertifikats- und Hostname-Prüfung sind immer aktiv; es gibt nirgends ein „accept all certificates“.
- Zugangsdaten und Token wandern nie in Logs, Exceptions, `toString()` oder Fehlermeldungen.
  Fehler sind klassifizierte Aufzählungswerte mit lokalisierten Texten, ohne Rohdaten der Quelle.
- Kein Hintergrund-Polling. Mail synchronisiert alle 10 Minuten, solange die App läuft; Noten und
  Moodle folgen einer 24-Stunden-Regel mit Single-Flight und manueller Übersteuerung.
- „Account entfernen“ bzw. „Verbindung und lokale Daten löschen“ entfernt Zugangsdaten, Token,
  Cache, Cache-Schlüssel, Zeitstempel und den zugehörigen State **vollständig**.

Die HIS-QIS-Integration ist **inhärent fragil**, weil das Portal keine JSON-API anbietet und über
Spaltenüberschriften geparst wird. Eine Portaländerung ist deshalb zuerst als Quelländerung zu
behandeln, nicht als eigener Bug; sie führt zu `portalStructureChanged` und **überschreibt den
Cache nicht**. Dasselbe gilt für die WebUntis-View-API in Pfad 1.

## 4. Datenhaltung

### 4.1 Trennung

| Datenbank          | Rolle        | Inhalt                                                            | Zugriff durch           |
| ------------------ | ------------ | ----------------------------------------------------------------- | ----------------------- |
| `campus_cms_<env>` | `campus_cms` | Strapi-Tabellen, redaktionelle Inhalte                            | nur Strapi              |
| `campus_app_<env>` | `campus_app` | importierte Mensa-, Stundenplan- und Kalenderdaten, Sync-Zustände | nur Campus API + Worker |

Redaktionelle Inhalte werden **nicht** in die operative Datenbank gespiegelt. Die API liest sie bei
Bedarf über Strapi. Die **einzige** Ausnahme ist der Katalog der öffentlichen Kalender: Er wird als
minimales operatives Read-Model gespiegelt, damit ein Kalender erst nach Validierung **und** erstem
erfolgreichen ICS-Sync erscheint und ein Strapi-Ausfall die öffentliche API nicht lahmlegt.

**Persönliche Daten aus Pfad 2 liegen in keiner dieser Datenbanken.** Es gibt weder Tabelle noch
Spalte für E-Mails, Noten oder Moodle-Inhalte — sie existieren ausschließlich auf dem Gerät.

### 4.2 Operatives Schema (Prisma)

13 Modelle in drei fachlichen Gruppen. Vollständig: [`../apps/backend/prisma/schema.prisma`](../apps/backend/prisma/schema.prisma).

**Mensa**

```text
Canteen                 slug (unique), sourceLocationId (unique), displayName, campusLabel, active
Meal                    sourcePlanId (unique) ← Upsert-Schlüssel, canteenId, date, counterId,
                        isSprint, name, subtitle, extras[], ingredientCodes[],
                        sourceUpdatedAt, importedAt
MealPrice               mealId + group (unique), amount (Decimal) — jede Preisgruppe eine Zeile,
                        eine fehlende Gruppe ist eine fehlende Zeile, nie ein geschätzter Wert
IngredientDefinition    code (PK), labelDe, labelEn?, kind (ingredient | marker)
SyncRun                 source, canteenId?, startedAt, finishedAt, status, recordsReceived,
                        recordsUpserted, recordsRejected, errorMessage
```

**Stundenplan (WebUntis, öffentliche Ansicht)**

```text
TimetableContext        source + externalId (unique), Schuljahr, validFrom/validTo — die ID ist
                        dynamisch und wird zur Laufzeit gelesen, nie hartkodiert
TimetableGroup          source + externalId (unique), shortName, longName, department, active,
                        lastSeenAt — Deaktivierung erst nach vollständigem Erfolgslauf
TimetableEntry          source + externalKey (unique) ← Upsert-Schlüssel, startsAt/endsAt (UTC),
                        date, title, subjectCode, type, status, sourceStatus, teachers, rooms
TimetableEntryGroup     explizite n:m — ohne sie würde ein Gruppensync eine Stunde löschen,
                        die andere Gruppen noch besuchen
TimetableSyncRun        kind (context | groups | entries), status, bestätigtes Fenster, Zähler,
                        klassifizierter Fehlercode
```

**Öffentliche Kalender (öffentlicher Google-ICS-Feed)**

```text
PublicCalendar          slug (unique), googleCalendarId (nur serverseitig), Anzeigefelder,
                        operationalStatus, lastEtag/lastModified/lastContentHash,
                        lastSuccessfulSyncAt
PublicCalendarEvent     calendarId + occurrenceKey (unique), uid, recurrenceId, title,
                        description?, location?, startsAt/endsAt, allDay, status
PublicCalendarSyncRun   kind (catalog | events), status, Fenster, Zähler, redigierter Fehler
```

Durchgehende Regeln:

- Geldwerte sind `Decimal`, niemals `float`.
- `Meal.imageUrl` existiert **nicht** — die Bild-URL der Quelle wird bewusst nicht persistiert.
- Externe IDs werden gespeichert, damit Upserts stabil bleiben, aber **nie** ausgeliefert. Clients
  sehen ausschließlich Campus-UUIDs und Slugs.
- Roh-ICS wird **nie** gespeichert; `ATTENDEE`/`ORGANIZER` werden nicht einmal gelesen.
- Jede `*SyncRun`-Tabelle speichert nur Zähler und einen klassifizierten Fehler — nie Header, URLs,
  Rohdaten oder Personennamen.

### 4.3 Gerätelokale Speicher (Pfad 2 und lokale Funktionen)

| Daten                                                 | Speicher                                     |
| ----------------------------------------------------- | -------------------------------------------- |
| Zugangsdaten Mail, HIS-QIS · Moodle-Token             | `flutter_secure_storage` (Keychain/Keystore) |
| Schlüssel der verschlüsselten Boxen (256 Bit, CSPRNG) | `flutter_secure_storage`                     |
| Noten, Moodle-Inhalte                                 | verschlüsselte `hive_ce`-Box                 |
| E-Mail-Kopfzeilen, -Inhalte, optional Anhänge         | app-private `hive_ce`-Box                    |
| Aufgabenliste                                         | `hive_ce`, rein lokal, ohne Netz             |
| News, Kanäle, Kontakte, Mensadaten                    | `hive_ce` (Inhaltscache)                     |
| Kanal-Abos, Kalenderauswahl, Sprache, Theme, Mensa    | `SharedPreferences` (kleine Skalare)         |

Ein Cachefehler darf **nie** zum Absturz führen — er degradiert auf einen Netzabruf. Umgekehrt
**löscht** eine leere, ungültige oder fehlgeschlagene Antwort **nie** den letzten guten Stand.

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

## 6. Resilienz der Synchronisierung

Alle drei Worker-Jobs folgen demselben Grundsatz: **eine leere, ungültige oder fehlgeschlagene
Fremdantwort löscht niemals den letzten erfolgreichen Datenbestand.** Aufgeräumt wird nur innerhalb
eines bestätigten Zeitfensters und nur nach einer erfolgreichen, nicht-leeren Antwort. Dieser Punkt
ist für jeden Job durch Integrationstests gegen eine echte Datenbank abgesichert.

### 6.1 Mensa

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

### 6.2 Stundenplan

Zwei getrennte Jobs, beide über `WEBUNTIS_ENABLED` schaltbar (Default `false`):

- **Gruppenkatalog** (`WEBUNTIS_GROUP_SYNC_CRON`, Default `0 3,15 * * *`) — eine Gruppe wird erst
  nach einem **vollständig** erfolgreichen Katalogimport deaktiviert, nie aufgrund eines Teillaufs.
- **Einträge** (`WEBUNTIS_ENTRY_SYNC_CRON`) — **ein** Request pro Lauf für alle Gruppen. Die Quelle
  liefert alle Klassen auf einmal (Größenordnung 270 Klassen, ~505 KB), deshalb ist ein Batch pro
  Zeitfenster deutlich schonender als Einzelabrufe.

Die Schuljahres-ID ist dynamisch und wird zur Laufzeit gelesen. Zeiten kommen als zonenlose
Wandzeit und werden beim Import nach UTC gerechnet — würde man sie roh speichern, verschöbe sich
jede Stunde. Unbekannte Vokabeln in `type`/`status` werden auf `unknown` abgebildet und brechen den
Import **nicht**.

### 6.3 Öffentliche Kalender

Zwei getrennte Jobs, beide über `PUBLIC_CALENDAR_ENABLED` schaltbar (Default `false`):

- **Katalog** — spiegelt validierte Strapi-Definitionen ins operative Read-Model. Eine fehlerhafte
  oder unvollständige Strapi-Antwort löscht den letzten gültigen Katalog nie.
- **Events** — pro Kalender: ICS laden (bytebegrenzt) → validieren → parsen → im Zielfenster
  expandieren → **eine Transaktion** aus Upsert und Löschen ausschließlich im bestätigten Fenster.

Bemerkenswerte Zustände:

| Fall                                | Verhalten                                                              |
| ----------------------------------- | ---------------------------------------------------------------------- |
| Gültiger leerer Feed                | erfolgreicher leerer Snapshot, **kein** Fehler                         |
| Unveränderter Hash / HTTP 304       | teure Parse-/Persistenzphase überspringen, Zeitstempel trotzdem setzen |
| Timeout, Netzfehler, 5xx, 429       | letzten Stand behalten, Kalender `stale`, weiter ausliefern            |
| Beschädigt, zu groß, Limit gerissen | keine destruktive Übernahme; `stale` bzw. `invalid` ohne Vorstand      |
| Freigabe entzogen (403, 404, 410)   | Status `revoked`/`unavailable`, Termine gelöscht, aus dem Katalog raus |

Der ICS-Client folgt **keinen** Redirects (3xx wird abgelehnt), konstruiert Scheme, Host und Pfad
selbst und nimmt **keine** Basis-URL aus Strapi oder dem Environment entgegen. Wiederholungsregeln
werden nur im Zielfenster expandiert, mit harten Obergrenzen pro Event und pro Lauf gegen
„recurrence bombs“. Details: [public-calendars.md](public-calendars.md).

## 7. Betrieb

### 7.1 Container

| Image                                      | Port           | Health                                  | User     |
| ------------------------------------------ | -------------- | --------------------------------------- | -------- |
| `ghcr.io/erikenglerdev/campus-app-cms`     | `0.0.0.0:1337` | `GET /_health`                          | non-root |
| `ghcr.io/erikenglerdev/campus-app-backend` | `0.0.0.0:3000` | `GET /health/live`, `GET /health/ready` | non-root |
| `postgres:16-alpine` (offiziell, gepinnt)  | intern         | `pg_isready`                            | —        |

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

| Thema                                           | Status                                                                                                    |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Redis                                           | nicht im MVP — kein Caching-Layer nötig, Datenmengen sind klein                                           |
| SMTP                                            | später — Strapi-Admins werden zunächst manuell angelegt                                                   |
| Sentry / Analytics                              | dauerhaft ausgeschlossen im MVP                                                                           |
| Automatisches Deployment                        | ausgeschlossen — Images werden gebaut, Deployment bleibt manuell                                          |
| Offsite-Backups                                 | offenes Release-Gate, **nicht** eingerichtet                                                              |
| WebUntis-Stundenplan                            | vollständig umgesetzt, aber `WEBUNTIS_ENABLED=false` bis zur organisatorischen Freigabe                   |
| Öffentliche Kalender                            | vollständig umgesetzt, aber `PUBLIC_CALENDAR_ENABLED=false` bis Kalender in Strapi gepflegt sind          |
| Google API Key / OAuth / SDK                    | dauerhaft ausgeschlossen — der Worker liest ausschließlich den öffentlichen ICS-Feed                      |
| Backend-Proxy für Mail, Noten, Moodle           | dauerhaft ausgeschlossen — genau deshalb laufen diese Dienste direkt vom Gerät                            |
| Hintergrund-Sync bei geschlossener App          | ausgeschlossen — bräuchte WorkManager/BGTaskScheduler; Sync läuft, solange die App läuft, plus beim Start |
| Schreibzugriffe auf Moodle                      | ausgeschlossen — nur eine feste, rein lesende Whitelist von `wsfunction`s                                 |
| Persönlicher WebUntis-Login                     | außerhalb des MVP; genutzt wird ausschließlich die öffentliche Gruppenansicht                             |
| Raumpläne, Raumverfügbarkeit, Indoor-Navigation | außerhalb des MVP; Architektur bleibt erweiterbar                                                         |
