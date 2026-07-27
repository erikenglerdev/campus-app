<!-- Campus Köthen App · AGPL-3.0-only · Copyright © 2026 Erik Engler and Jona Loreen Sommer -->

# Öffentliche Google-Kalender (ICS)

Redakteur:innen legen in Strapi **öffentliche** Google-Kalender an. Der Campus-Worker
synchronisiert sie über den **öffentlichen ICS-Feed**, die Campus API liefert Katalog und Termine,
und die App führt sie – lokal – mit Stundenplan und Moodle-Deadlines im Kalender-Tab zusammen. Nach
der einmaligen Implementierung braucht ein weiterer Kalender **weder App- noch Backend-Änderung**.

## 1. Erlaubter Datenfluss

```
Strapi (public-calendar)  ──▶  Campus-Worker  ──ICS──▶  calendar.google.com (public/basic.ics)
   Definitionen                 │  validiert, parst, normalisiert
                                ▼
                          PostgreSQL (operatives Read-Model)  ──▶  Campus API  ──▶  Flutter
```

- **Kein** Google API Key, **kein** Google-Cloud-Projekt, **kein** Google-OAuth, **kein** SDK.
- Die **App ruft den ICS-Feed nie direkt ab**. Nur der Worker lädt ihn.
- Google-Kalender-ID und Feed-URL bleiben **backendintern** (nie ein DTO-Feld, nie geloggt).
- Zusammenführung mit Stundenplan/Moodle passiert **ausschließlich lokal** in Flutter.

## 2. Von der Freigabe zur Feed-URL

Redakteur:innen tragen einen **öffentlichen Freigabelink** ein, z. B.
`https://calendar.google.com/calendar/u/0?cid=<base64url>`. Aus dem `cid` wird die Kalender-ID
extrahiert und daraus **serverseitig** die feste Feed-URL konstruiert:

```
https://calendar.google.com/calendar/ical/{URL-kodierte-ID}/public/basic.ics
```

Validierung (`google-calendar-url.ts`, 36 Tests): HTTPS-only · Host **exakt** `calendar.google.com`
· kein Userinfo/Port · Pfad-Allowlist (`render`, `u/N`, `u/N/r`) · genau **ein** `cid` · Base64/-URL
mit kanonischem Roundtrip · striktes UTF-8 · Längenlimits · keine Steuerzeichen/Whitespace. Abgelehnt
werden u. a. `http`, `webcal`, `calendar.google.com.attacker.example`, `user@…`, Ports, IPs sowie
direkt eingefügte `basic.ics`-/`private-…`-Links. Dieselbe Validierung läuft **erneut** an der
Backend-Vertrauensgrenze (`validateCatalog`).

## 3. SSRF-Schutz & ICS-Client

`GooglePublicIcsClient` (12 Tests): fester Scheme+Host+Pfad · Kalender-ID als **einziges**
`encodeURIComponent`-Pfadsegment · **keine** Basis-URL aus Strapi/ENV · Redirects werden **nicht**
verfolgt (3xx → abgelehnt) · harte Timeouts, begrenzte Retries (nur 5xx/429/Transport),
Request-Abstand · `Content-Length`-Vorabprüfung **und** Streaming-Byte-Limit (Abbruch bei
Überschreitung) · `Content-Type: text/calendar` (tolerant nur bei gültigem VCALENDAR-Body) ·
ETag/Last-Modified + `If-None-Match`/`If-Modified-Since` + **304** · Feed-URL/ID nie in Fehlern.

## 4. RFC-5545-Parser

`ics-parser.ts` nutzt **`ical.js`** (Mozilla, MPL-2.0, **null** Laufzeit-Abhängigkeiten) – **keine**
naive Zeilentrennung. Unterstützt (17 Tests): Zeilenfaltung, Escaping, Parameter, `VTIMEZONE`, UTC,
TZID, floating (mit kontrollierter Fallback-Zeitzone), `VALUE=DATE` mit **exklusivem** `DTEND`,
`DTSTART`+`DURATION`, `RRULE`/`RDATE`/`EXDATE`, `RECURRENCE-ID` (verschoben/abgesagt), abgesagte
Events, `SEQUENCE`/`LAST-MODIFIED`, DST-Wechsel. **Netzwerkfunktionen des Parsers werden nicht
verwendet** – ihm wird nur der bereits geladene, größenbegrenzte Text übergeben.

- **Wiederholungen** werden **nur** im Zielzeitfenster expandiert; harte Obergrenzen pro Event und
  pro Lauf stoppen „recurrence bombs“ (`FREQ=MINUTELY` → `recurrenceLimitExceeded`).
- **Ganztägig:** lokales Kalenderdatum, exklusives Enddatum, keine UTC-/Gerätezeitzonen-Verschiebung.
- **Datenminimierung:** `ATTENDEE`/`ORGANIZER`/`CONTACT`/`ATTACH`/Konferenz/Alarme/`X-*` werden
  **nie gelesen** → keine E-Mail-Adressen. `DESCRIPTION`/`LOCATION` nur bei entsprechendem
  Strapi-Flag, immer als **Plain Text** (nie HTML).

## 5. Strapi = Quelle, PostgreSQL = resilientes Read-Model

Strapi ist die kanonische redaktionelle Quelle. Der Worker spiegelt **validierte** Definitionen in
ein minimales operatives Read-Model (`PublicCalendar`), damit ein Kalender erst nach Validierung
**und** erstem erfolgreichen ICS-Sync erscheint und ein Strapi-Ausfall die öffentliche API nicht
lahmlegt. Eine fehlerhafte/leere/unvollständige Strapi-Antwort **löscht den letzten gültigen Katalog
nie**; erst ein vollständig erfolgreicher Abruf fügt hinzu/aktualisiert/deaktiviert. Roh-ICS wird
**nie** gespeichert.

## 6. Worker-Sync & Reconciliation (10 Integrationstests, echte DB)

- Getrennte Jobs `catalog` und `events`, per `PUBLIC_CALENDAR_ENABLED` schaltbar, eigener
  Overlap-Guard, unabhängig von Canteen/Timetable.
- Pro Kalender: SyncRun `running` → ICS laden (bytebegrenzt) → validieren → parsen → im Zielfenster
  expandieren → **Transaktion**: upsert + Löschen **nur** im bestätigten Fenster für nicht mehr
  gesehene `occurrenceKey` → Status/`lastSuccessfulSyncAt` setzen.
- **Gültiger leerer** Feed = erfolgreicher leerer Snapshot (kein Fehler).
- **Unveränderter Hash/304** = teure Parse-/Persistenzphase überspringen, Status/Zeitstempel trotzdem
  aktualisieren.
- **Temporärer Fehler** (Timeout/Netz/5xx/429): letzten Stand behalten, Kalender `stale`, weiter
  ausliefern.
- **Beschädigt/zu groß/Recurrence-Limit:** keine destruktive Übernahme; `stale` (mit Vorstand) bzw.
  `invalid` (ohne) — bei erstem Sync nicht öffentlich.
- **Freigabe entzogen** (404/410/403): Status `revoked`/`unavailable`, Termine gelöscht, aus dem
  öffentlichen Katalog entfernt.

## 7. Campus API

- `GET /v1/calendars` — Katalog (nur aktive, valide, mind. einmal erfolgreich synchronisierte).
  DTO: `id, slug, name, description, colorHex, iconKey, sortOrder, defaultSubscribed, attribution,
dataState, lastSuccessfulSyncAt, dataStale, googleOpenUrl`. **Nie** Google-ID, Feed-URL,
  `ownerContact`, ETag oder interne Fehler.
- `GET /v1/calendars/:slug/events?from&to` — Termine eines Kalenders (Zeitraum begrenzt).
- `GET /v1/calendars/events?calendar=…&calendar=…&from&to` — aggregiert; Slugs dedupliziert,
  begrenzt; **leere Auswahl ⇒ leere Liste** (nie „alle“); pro Termin `calendarId`+`calendarSlug`;
  deterministisch sortiert; keine Live-/N+1-Abfrage.
- `GET /v1/calendars/google-view-url?calendar=…` — serverseitig konstruierte
  `calendar.google.com/embed`-URL (ein `src` je Kalender, `ctz`), nur aktive/öffentliche Kalender.

## 8. App

- **Kalender-Tab:** dynamische Quelle neben Stundenplan und Moodle. Öffentliche Termine erhalten
  einen Farbpunkt **plus** Kalendername/Icon (Farbe nie alleiniges Merkmal). Ein Fehler der
  öffentlichen Quelle blendet Stundenplan/Moodle **nicht** aus.
- **„Kalender verwalten“:** Y-aus-X-Auswahl lokal (SharedPreferences). `defaultSubscribed` greift
  **genau einmal** pro Slug (seen-Ledger); bewusst deaktivierte bleiben aus; verschwundene Slugs
  werden tolerant bereinigt; ein Backend-Update überschreibt die Auswahl nie; keine Auswahl ⇒ keine
  öffentlichen Termine.
- **Google-Buttons:** „In Google Kalender öffnen“ (einzeln, `googleOpenUrl`) und „Ausgewählte in
  Google Kalender öffnen“ (kombinierte Embed-URL vom Backend), extern via `url_launcher`
  (HTTPS, Browser-Fallback). Kein automatisches Hinzufügen zum persönlichen Google-Konto; Stundenplan
  und Moodle sind keine Google-Quellen und nicht Teil der kombinierten Ansicht.

## 9. Strapi-Redaktionshandbuch

1. Strapi öffnen → **Public Calendar → Create an entry**.
2. **Name** (lokalisiert) und **Slug** (nur `a-z0-9-`, stabil, nach Veröffentlichung nicht mehr
   ändern) eintragen.
3. **googleShareUrl**: den **öffentlichen** Google-Freigabelink mit `cid` einfügen
   (`https://calendar.google.com/calendar/u/0?cid=…`). **Keine** geheime/private „iCal-Adresse“ und
   **keine** `basic.ics`-URL.
4. **colorHex** (`#RRGGBB`), **iconKey**, **sortOrder** wählen.
5. **defaultSubscribed** bewusst setzen (true = beim ersten Erscheinen automatisch aktiv).
6. **attribution** pflegen; **showDescription/showLocation** datensparsam entscheiden;
   **ownerContact** ist ein **privates** Feld (nicht in der API).
7. **Speichern und Veröffentlichen** (Draft & Publish).
8. Auf den **ersten erfolgreichen ICS-Sync** warten; danach erscheint der Kalender in `GET
/v1/calendars` und der App.
9. Bei Entzug der Freigabe: Eintrag deaktivieren (`isActive=false`) oder Freigabe klären.

Der serverseitige read-only Strapi-Token braucht **Leserechte** für veröffentlichte
`public-calendar`-Einträge. **Keine** öffentliche anonyme Strapi-Berechtigung aktivieren.

## 10. Veröffentlichungsrechte

Technisch öffentlich lesbar ≠ rechtlich frei weiterveröffentlichbar. Vor dem produktiven Eintrag
organisatorisch klären: Zustimmung des Inhabers, zulässiger Quellenhinweis, ob Beschreibung/Ort
gezeigt werden dürfen, Ansprechpartner, Verhalten bei Entzug. Teilnehmer-/Organizer-E-Mail-Adressen
werden **nie** übernommen oder veröffentlicht.

## 11. Konfiguration & Abhängigkeit

ENV (siehe `apps/backend/.env.example`): `PUBLIC_CALENDAR_ENABLED` und der `PUBLIC_CALENDAR_*`-Block.
Für DEV muss `PUBLIC_CALENDAR_ENABLED=true` gesetzt und der Strapi-Token mit Leserechten versehen
werden. Neue Abhängigkeit: **`ical.js@2.2.1` (MPL-2.0, keine transitiven Laufzeit-Deps)** — Bewertung
in [`legal/dependency-licenses.md`](legal/dependency-licenses.md).
