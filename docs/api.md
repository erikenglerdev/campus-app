# Campus API — Vertrag

Campus Köthen App · `AGPL-3.0-only` · Basis-Pfad `/v1`

Dies ist der **verbindliche Vertrag** zwischen Campus API und Flutter-Client. Die maschinenlesbare
Fassung liegt in [`packages/openapi/openapi.json`](../packages/openapi/openapi.json) und wird aus
den NestJS-DTOs erzeugt.

---

## 1. Grundregeln

| Regel                  |                                                                                         |
| ---------------------- | --------------------------------------------------------------------------------------- |
| Basis-Pfad für Inhalte | `/v1`                                                                                   |
| Technische Endpunkte   | `/health/live`, `/health/ready`, `/docs`, `/docs-json` (ohne `/v1`)                     |
| Format                 | `application/json; charset=utf-8`                                                       |
| Authentifizierung      | keine — alle Inhalte sind öffentlich lesbar                                             |
| Strapi-Internas        | **niemals** in der Antwort (`data.attributes`, `documentId`, `populate`, Strapi-`meta`) |

Jede **inhaltliche** Antwort verwendet denselben Umschlag:

```jsonc
{
  "data": {/* oder [] */},
  "meta": {
    "requestedLocale": "de",
    "resolvedLocale": "de",
    "translationFallback": false,
  },
}
```

## 2. Locale-Vertrag

Auflösung in dieser Reihenfolge:

1. Query-Parameter `locale` — Werte `de` oder `en`.
2. Header `Accept-Language` — nur wenn kein `locale`-Parameter gesetzt ist.
3. Standard `de`.

| Fall                              | Verhalten                                                             |
| --------------------------------- | --------------------------------------------------------------------- |
| `?locale=de` / `?locale=en`       | wird verwendet                                                        |
| `?locale=fr`                      | **`400 Bad Request`** — expliziter Wunsch wird nicht still verfälscht |
| `Accept-Language: fr-FR`          | stiller Fallback auf `de`                                             |
| `Accept-Language: en-GB,en;q=0.9` | `en`                                                                  |
| kein Hinweis                      | `de`                                                                  |

Metadaten jeder inhaltlichen Antwort:

| Feld                  | Bedeutung                                                                                        |
| --------------------- | ------------------------------------------------------------------------------------------------ |
| `requestedLocale`     | was der Client wollte                                                                            |
| `resolvedLocale`      | was tatsächlich ausgeliefert wurde                                                               |
| `translationFallback` | `true`, sobald **mindestens ein** ausgeliefertes Feld aus `de` stammt, obwohl `en` angefragt war |

**Externe Mensa-Texte werden nie übersetzt.** Gerichtsnamen, Zusatztexte und Zutaten-/Markerlabels
stammen aus einer rein deutschsprachigen Quelle. Bei `locale=en` sind sie immer Fallback; das
betroffene Objekt trägt zusätzlich `"sourceLanguage": "de"`. API-eigene Texte (Mensanamen,
Preisgruppen-Labels, Fehlermeldungen) sind zweisprachig.

## 3. Fehlerformat

```jsonc
{
  "error": {
    "status": 404,
    "code": "NEWS_ARTICLE_NOT_FOUND",
    "message": "Der angeforderte Beitrag wurde nicht gefunden.",
    "requestId": "b1f0…",
  },
}
```

`message` ist in der aufgelösten Locale. Es werden **nie** interne Details, Stacktraces,
Upstream-URLs oder Tokens ausgegeben.

| Code                                                                      | Status |
| ------------------------------------------------------------------------- | ------ |
| `VALIDATION_FAILED`                                                       | 400    |
| `UNSUPPORTED_LOCALE`                                                      | 400    |
| `NEWS_ARTICLE_NOT_FOUND` / `CONTACT_AREA_NOT_FOUND` / `CANTEEN_NOT_FOUND` | 404    |
| `UPSTREAM_UNAVAILABLE`                                                    | 503    |
| `UPSTREAM_TIMEOUT`                                                        | 504    |

## 4. Technische Endpunkte

### `GET /health/live`

Prüft **ausschließlich** den Prozess. Immer `200`, solange der Prozess antwortet.

```json
{ "status": "ok", "uptimeSeconds": 1234 }
```

### `GET /health/ready`

Prüft Datenbank und Strapi kontrolliert mit Timeout. `200` wenn bereit, sonst `503`.

```jsonc
{
  "status": "ok", // "ok" | "degraded"
  "checks": {
    "database": { "status": "ok", "latencyMs": 3 },
    "strapi": { "status": "ok", "latencyMs": 41 },
  },
}
```

### `GET /docs` · `GET /docs-json`

Swagger UI und OpenAPI-3-Dokument.

## 5. News

### `GET /v1/news/channels`

Nur **aktive** Kanäle, sortiert nach `sortOrder`, dann `name`.

```jsonc
{
  "data": [
    {
      "slug": "campus-news",
      "name": "Campus News",
      "description": "Nachrichten rund um den Campus Köthen.",
      "iconKey": "campus",
      "colorHex": "#5B3FD0",
      "sortOrder": 10,
      "defaultSubscribed": true,
    },
  ],
  "meta": { "requestedLocale": "de", "resolvedLocale": "de", "translationFallback": false },
}
```

`slug` ist stabil und **nicht** lokalisiert. `defaultSubscribed` wird vom Client pro Slug
**genau einmal** ausgewertet — beim erstmaligen Auftauchen.

### `GET /v1/news`

| Parameter  | Typ           | Standard | Regeln             |
| ---------- | ------------- | -------- | ------------------ |
| `channels` | CSV von Slugs | _fehlt_  | siehe unten        |
| `page`     | Integer >= 1  | `1`      |                    |
| `pageSize` | Integer 1–50  | `20`     | Werte > 50 ⇒ `400` |
| `locale`   | `de` \| `en`  | `de`     |                    |

**Verhalten von `channels` — vertraglich festgeschrieben:**

| Anfrage                        | Bedeutung                             |
| ------------------------------ | ------------------------------------- |
| Parameter **fehlt**            | alle aktiven Kanäle                   |
| `?channels=` (vorhanden, leer) | **bewusst keine** Kanäle ⇒ `data: []` |
| `?channels=campus-news`        | nur dieser Kanal                      |
| unbekannter Slug enthalten     | wird ignoriert, kein Fehler           |

Der Unterschied zwischen „fehlt“ und „leer“ ist wichtig: Deaktiviert der Nutzer **alle** Kanäle,
sendet der Client `?channels=` und erhält eine leere Liste — er darf **nicht** versehentlich alle
News laden.

Nur veröffentlichte und zeitlich gültige Beiträge (`validFrom` <= jetzt <= `validUntil`).
Beiträge in mehreren angefragten Kanälen erscheinen **genau einmal**.
Sortierung: `isPinned` DESC, dann `publishedAt` DESC, dann `slug` ASC (deterministisch).

```jsonc
{
  "data": [
    {
      "slug": "semesterstart-2026",
      "title": "Semesterstart 2026",
      "teaser": "Was zum Start des Wintersemesters wichtig ist.",
      "publishedAt": "2026-07-20T09:00:00.000Z",
      "isPinned": true,
      "heroImage": { "url": "https://…", "alternativeText": "…", "width": 1600, "height": 900 },
      "channels": [{ "slug": "campus-news", "name": "Campus News", "colorHex": "#5B3FD0" }],
      "authors": [{ "name": "Redaktion Campus News", "role": "Redaktion" }],
      "sourceName": "Hochschule Anhalt",
      "sourceUrl": "https://www.hs-anhalt.de/…",
    },
  ],
  "meta": {
    "requestedLocale": "de",
    "resolvedLocale": "de",
    "translationFallback": false,
    "pagination": { "page": 1, "pageSize": 20, "total": 1, "totalPages": 1 },
  },
}
```

`heroImage` ist `null`, wenn kein freigegebenes Bild hinterlegt ist.
`sourceUrl` ist immer eine validierte **HTTPS**-URL oder `null`.

### `GET /v1/news/:slug`

Wie ein Listeneintrag, zusätzlich `content`. Unbekannter Slug ⇒ `404 NEWS_ARTICLE_NOT_FOUND`.

```jsonc
{
  "data": {
    "slug": "semesterstart-2026",
    "title": "…",
    "teaser": "…",
    "publishedAt": "…",
    "isPinned": true,
    "heroImage": null,
    "channels": [],
    "authors": [],
    "sourceName": null,
    "sourceUrl": null,
    "content": [
      { "type": "heading", "level": 2, "children": [{ "type": "text", "text": "Überblick" }] },
      {
        "type": "paragraph",
        "children": [
          { "type": "text", "text": "Normaler Text " },
          { "type": "text", "text": "fett", "bold": true },
          {
            "type": "link",
            "url": "https://example.org",
            "children": [{ "type": "text", "text": "Quelle" }],
          },
        ],
      },
      {
        "type": "list",
        "format": "unordered",
        "children": [{ "type": "list-item", "children": [{ "type": "text", "text": "Punkt" }] }],
      },
      { "type": "quote", "children": [{ "type": "text", "text": "Zitat" }] },
      { "type": "image", "url": "https://…", "alternativeText": "…", "width": 800, "height": 600 },
    ],
  },
  "meta": { "…": "…", "droppedBlockTypes": [] },
}
```

**Unterstützte Blocktypen im MVP:** `paragraph`, `heading`, `list`, `list-item`, `quote`, `image`
sowie inline `text` und `link`.

Unbekannte Blocktypen werden **serverseitig verworfen** und in `meta.droppedBlockTypes` gemeldet.
Der Client rendert damit nie einen unbekannten Typ; eine neue Strapi-Blockart kann die Detailseite
nicht zerstören. Inline-`link`-URLs werden auf `https:`, `mailto:` und `tel:` beschränkt.

## 6. Kontakte

### `GET /v1/contact-areas`

Nur aktive Bereiche, sortiert nach `sortOrder`, dann `name`.

```jsonc
{
  "data": [
    {
      "slug": "studierendenrat",
      "name": "Studierendenrat",
      "shortDescription": "Die gewählte Vertretung der Studierendenschaft.",
      "iconKey": "students-council",
      "sortOrder": 10,
      "generalEmail": null,
      "phone": null,
      "website": null,
      "appointmentUrl": null,
      "address": null,
      "openingHours": null,
      "personCount": 0,
      "isDemoContent": true,
    },
  ],
  "meta": { "…": "…" },
}
```

Alle Kontaktfelder sind **optional** und `null`, wenn nicht gepflegt. Ein Bereich **ohne**
Kontaktperson ist gültig (`personCount: 0`) und muss im Client vollständig nutzbar bleiben.
`isDemoContent: true` markiert nicht freigegebene Startdaten — der Client zeigt dafür einen
sichtbaren Hinweis.

### `GET /v1/contact-areas/:slug`

Zusätzlich `description` (Blocks, gleiche Regeln wie News-`content`) und `persons` — nur aktive
Personen, sortiert nach `sortOrder`, dann `name`.

```jsonc
{
  "data": {
    "slug": "studierendenrat",
    "name": "…",
    "shortDescription": "…",
    "iconKey": "…",
    "generalEmail": null,
    "phone": null,
    "website": null,
    "appointmentUrl": null,
    "address": null,
    "openingHours": null,
    "isDemoContent": true,
    "description": [],
    "persons": [
      {
        "name": "…",
        "role": "…",
        "description": null,
        "email": null,
        "phone": null,
        "website": null,
        "profileImage": null,
      },
    ],
  },
  "meta": { "…": "…" },
}
```

Eine Person kann in **mehreren** Bereichen erscheinen.

## 7. Mensa

### `GET /v1/canteens`

Ausschließlich aus Backend-Daten. Der Client kennt **keine** `location_id`.

```jsonc
{
  "data": [
    {
      "slug": "koethen-fasanerieallee",
      "displayName": "Mensa Köthen",
      "campusLabel": "Fasanerieallee",
      "lastSuccessfulSyncAt": "2026-07-22T12:00:04.000Z",
      "dataStale": false,
    },
  ],
  "meta": { "…": "…" },
}
```

`displayName` und `campusLabel` sind API-eigene, zweisprachige Texte.

### `GET /v1/canteens/:slug/menu`

| Parameter | Typ          | Standard         | Regeln                                              |
| --------- | ------------ | ---------------- | --------------------------------------------------- |
| `from`    | `YYYY-MM-DD` | heute            |                                                     |
| `to`      | `YYYY-MM-DD` | `from` + 13 Tage | `to >= from`, Spanne **max. 31 Tage** ⇒ sonst `400` |
| `locale`  | `de` \| `en` | `de`             |                                                     |

```jsonc
{
  "data": {
    "canteen": { "slug": "…", "displayName": "…", "campusLabel": "…" },
    "days": [
      {
        "date": "2026-07-20",
        "meals": [
          {
            "id": "58033",
            "name": "Bulgur-Pfanne",
            "subtitle": "mit Kichererbsen, Wirsing und Kräuterdip",
            "sourceLanguage": "de",
            "counterId": 44,
            "isSprint": true,
            "extras": [],
            "markers": [
              { "code": "52", "label": "vegan", "kind": "ingredient" },
              { "code": "53", "label": "Sprint-Menü", "kind": "marker" },
              { "code": "A1", "label": "enthält Weizengluten", "kind": "ingredient" },
            ],
            "prices": [
              { "group": "student", "label": "Studierende", "amount": "1.95", "currency": "EUR" },
              { "group": "employee", "label": "Bedienstete", "amount": "4.95", "currency": "EUR" },
              { "group": "guest", "label": "Gäste", "amount": "7.00", "currency": "EUR" },
            ],
          },
        ],
      },
    ],
  },
  "meta": {
    "requestedLocale": "en",
    "resolvedLocale": "en",
    "translationFallback": true,
    "lastSuccessfulSyncAt": "2026-07-22T12:00:04.000Z",
    "dataStale": false,
    "from": "2026-07-20",
    "to": "2026-08-02",
  },
}
```

Verbindliche Regeln:

- **Es gibt kein Bildfeld.** `food.image_url` der Quelle wird weder gespeichert noch ausgeliefert.
- `amount` ist ein **String in Dezimaldarstellung**, damit keine Float-Rundung entsteht. Die
  Formatierung übernimmt der Client locale-gerecht.
- Es werden **alle** in der Quelle vorhandenen Preisgruppen ausgeliefert. Fehlt eine Gruppe, fehlt
  der Eintrag — es wird **kein** Preis geschätzt. Der Client hebt `group: "student"` hervor.
- `group` ist ein stabiler technischer Schlüssel, `label` der übersetzte Anzeigetext.
- `markers` führt Zutaten und Marker in **einer** Liste mit unterscheidendem `kind`, weil die
  Quelle beide Namensräume in `food.ingredients` mischt.
- `sourceLanguage: "de"` zeigt an, dass `name`, `subtitle`, `extras` und `markers[].label` aus der
  deutschsprachigen Quelle stammen und **nicht** übersetzt wurden.
- Ein Tag **ohne** Gerichte erscheint als leeres `meals`-Array — ein echter leerer Tag ist damit
  vom Ladefehler unterscheidbar.
- `dataStale` ist `true`, wenn `lastSuccessfulSyncAt` älter als `CANTEEN_STALE_AFTER_MINUTES` ist.
  `lastSuccessfulSyncAt: null` bedeutet: noch nie erfolgreich synchronisiert.

## 8. Was der Client garantiert nicht braucht

- keine Strapi-URL, kein Strapi-Token
- keine `location_id`
- keine hartcodierte Kanal-, Mensa- oder Bereichsliste
- keine Kenntnis der Preisfeld-Nummerierung der Quelle

## 9. Stundenplan

Quelle ist die **öffentliche** WebUntis-Ansicht. Sie wird ausschließlich serverseitig abgerufen —
siehe [data-sources.md](data-sources.md). Der Client sieht **niemals** eine WebUntis-URL, einen
WebUntis-Header, eine Schuljahres-ID oder eine externe Gruppen-ID.

Das Feature ist über `WEBUNTIS_ENABLED` schaltbar und steht **standardmäßig auf `false`**, bis die
Nutzung organisatorisch freigegeben ist. Deaktiviert antworten die Endpunkte weiterhin mit `200`
und einem klaren Zustand — nicht mit einem Fehler, damit der Client das verständlich darstellen
kann statt wie ein Absturz.

### `GET /v1/timetable/groups`

| Parameter    | Typ                      | Regeln                                                      |
| ------------ | ------------------------ | ----------------------------------------------------------- |
| `query`      | String, max. 100 Zeichen | Suche über Kurzname, Langname und Bereich; case-insensitive |
| `department` | String                   | exakter Bereichsfilter (`shortName`)                        |
| `locale`     | `de` \| `en`             | wie überall                                                 |

Liefert alle aktiven Gruppen in **einer** Antwort (Größenordnung 270). Sortierung: `shortName` ASC.

```jsonc
{
  "data": [
    {
      "id": "8f1c…", // Campus-UUID, stabil
      "shortName": "AIN2 - BT",
      "longName": "AIN2-Angewandte Informatik Vertiefung: Biotechnologie",
      "department": "FB5", // oder null
    },
  ],
  "meta": {
    "requestedLocale": "de",
    "resolvedLocale": "de",
    "translationFallback": false,
    "featureEnabled": true,
    "lastSuccessfulSyncAt": "…",
    "dataStale": false,
  },
}
```

Es gibt **kein** Feld mit der WebUntis-ID.

### `GET /v1/timetable/entries`

| Parameter | Typ          | Regeln                                                                |
| --------- | ------------ | --------------------------------------------------------------------- |
| `groupId` | UUID         | **erforderlich**; unbekannt ⇒ `404 TIMETABLE_GROUP_NOT_FOUND`         |
| `from`    | `YYYY-MM-DD` | **erforderlich**                                                      |
| `to`      | `YYYY-MM-DD` | **erforderlich**, `to >= from`, Spanne max. **42 Tage** ⇒ sonst `400` |
| `locale`  | `de` \| `en` |                                                                       |

```jsonc
{
  "data": {
    "group": { "id": "8f1c…", "shortName": "AIN2 - BT", "longName": "…", "department": "FB5" },
    "days": [
      {
        "date": "2026-07-20",
        "entries": [
          {
            "id": "…",
            "start": "2026-07-20T08:00:00.000Z",
            "end": "2026-07-20T09:30:00.000Z",
            "timezone": "Europe/Berlin",
            "title": "Englisch als Fremdsprache",
            "subjectCode": "Englisch als Fremdsp",
            "type": "regular_teaching | additional | unknown",
            "status": "regular | changed | cancelled | unknown",
            "teachers": [{ "shortName": "D-Demo01", "displayName": "Demo Demoperson01" }],
            "rooms": [{ "shortName": "D-04/201", "longName": "Seminarraum VM/GIN" }],
            "groups": [{ "id": "8f1c…", "shortName": "AIN2 - BT" }],
            "note": null,
          },
        ],
      },
    ],
  },
  "meta": {
    "requestedLocale": "de",
    "resolvedLocale": "de",
    "translationFallback": true,
    "timezone": "Europe/Berlin",
    "from": "2026-07-20",
    "to": "2026-08-02",
    "lastSuccessfulSyncAt": "…",
    "dataStale": false,
    "dataState": "ready | pending | unavailable",
    "featureEnabled": true,
  },
}
```

Verbindliche Regeln:

- **Jeder Tag des Zeitraums** erscheint, auch ohne Einträge. Ein echter freier Tag ist dadurch vom
  Ladefehler unterscheidbar — dieselbe Regel wie beim Speiseplan.
- `start`/`end` sind **absolute UTC-Zeitpunkte**. Die fachliche Zone `Europe/Berlin` steht
  zusätzlich im Vertrag, weil die Quelle lokale Wandzeit ohne Zone liefert.
- `status` und `type` sind **normalisierte technische Schlüssel**. Ein unbekannter Quellwert wird
  auf `unknown` abgebildet und bricht nichts.
- `teachers`, `rooms`, `groups` und `title` stammen aus dem Fremdsystem und werden **nie**
  übersetzt. Deshalb ist `translationFallback` bei `locale=en` `true`.
- `dataState`:
  - `ready` — Daten liegen vor,
  - `pending` — Feature aktiv, aber noch kein erfolgreicher Lauf für diesen Zeitraum,
  - `unavailable` — Feature deaktiviert oder dauerhaft kein Datenstand.

### `GET /v1/timetable/status`

Öffentlicher, bewusst magerer Zustand. Enthält **keine** URLs, Header, externen IDs oder
Fehlerdetails der Quelle.

```jsonc
{
  "data": {
    "featureEnabled": true,
    "groupCount": 270,
    "lastGroupSyncAt": "2026-07-22T03:00:11.000Z",
    "lastEntrySyncAt": "2026-07-22T17:30:04.000Z",
    "dataStale": false,
    "coveredFrom": "2026-07-15",
    "coveredTo": "2026-08-19",
  },
  "meta": { "requestedLocale": "de", "resolvedLocale": "de", "translationFallback": false },
}
```

### Fehlercodes

| Code                        | Status                                                |
| --------------------------- | ----------------------------------------------------- |
| `TIMETABLE_GROUP_NOT_FOUND` | 404                                                   |
| `VALIDATION_FAILED`         | 400 (ungültiges Datum, `to < from`, Spanne > 42 Tage) |
