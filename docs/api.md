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

| Code                                                                         | Status |
| ---------------------------------------------------------------------------- | ------ |
| `VALIDATION_FAILED`                                                          | 400    |
| `UNSUPPORTED_LOCALE`                                                         | 400    |
| `NEWS_ARTICLE_NOT_FOUND` / `CONTACT_AREA_NOT_FOUND` / `CANTEEN_NOT_FOUND`    | 404    |
| `TIMETABLE_GROUP_NOT_FOUND` / `PUBLIC_CALENDAR_NOT_FOUND` / `ROOM_NOT_FOUND` | 404    |
| `UPSTREAM_UNAVAILABLE`                                                       | 503    |
| `UPSTREAM_TIMEOUT`                                                           | 504    |
| `INTERNAL_ERROR`                                                             | 500    |

Die vollständige, maßgebliche Liste steht in
[`apps/backend/src/common/errors/api-error.ts`](../apps/backend/src/common/errors/api-error.ts);
jede Meldung liegt dort zweisprachig vor.

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
      "content": [{ "type": "paragraph", "children": [{ "type": "text", "text": "…" }] }],
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

**`content` in der Liste.** Jeder Listeneintrag trägt seinen **serverseitig bereinigten**
Inhalt. Die App stellt Artikel im Feed direkt dar; ohne Content in der Liste bräuchte jede
sichtbare Karte einen eigenen Detailrequest. Die Bereinigung passiert an derselben Stelle wie
beim Detail — unbereinigte Strapi-Blocks erreichen nie einen Client. Unbekannte Blocktypen
werden entfernt und **einmal pro Antwort** in `meta.droppedBlockTypes` gemeldet, dedupliziert
und sortiert; ein neuer CMS-Blocktyp ist eine Eigenschaft der Antwort, nicht jedes einzelnen
Artikels, der ihn zufällig verwendet.

`teaser` und `authors` bleiben im Vertrag, damit CMS und API kompatibel bleiben. Die mobile
App stellt beide **nicht** dar.

### `GET /v1/news/:slug`

Liefert genau denselben Aufbau wie ein Listeneintrag. Der Endpunkt bleibt aus
Kompatibilitätsgründen bestehen, enthält aber nichts mehr, was die Liste nicht auch hat.
Unbekannter Slug ⇒ `404 NEWS_ARTICLE_NOT_FOUND`.

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

### `GET /v1/contact-areas/search-index`

Alles, was die Kontaktsuche treffen kann, in **einer** Antwort.

Der Listenendpunkt trägt bewusst keine Detaildaten. Eine Suche über Beschreibungen, Telefonnummern
oder Raumnummern müsste deshalb jeden Bereich einzeln nachladen — ein N+1 bei jedem Tastendruck.
Stattdessen lädt der Client diesen Index **einmal**, cacht ihn und sucht lokal.

```jsonc
{
  "data": [
    {
      "slug": "studierendenrat",
      "name": "…",
      "shortDescription": "…",
      "iconKey": "…",
      "descriptionText": "Wir helfen bei Anträgen.\nSprechzeiten nach Vereinbarung.",
      "generalEmail": null,
      "phone": null,
      "website": null,
      "appointmentUrl": null,
      "address": null,
      "openingHours": null,
      "rooms": [{ "roomKey": "…", "roomNumber": "B.201", "…": "…" }],
      "persons": [
        {
          "name": "…",
          "role": "…",
          "description": null,
          "email": null,
          "phone": null,
          "website": null,
          "rooms": [],
        },
      ],
    },
  ],
  "meta": { "…": "…" },
}
```

Verbindliche Regeln:

- **Nur aktive** Bereiche und **nur aktive** Personen.
- Ausschließlich **explizit gemappte, öffentliche** Felder. Keine Strapi-Internas, keine IDs.
- **Kein `profileImage`:** Nach einem Bild sucht niemand, und ein Index ist der falsche Ort, um
  mehr herauszugeben als die Frage braucht.
- `descriptionText` ist die **bereinigte** Beschreibung als Klartext. Eine Suche trifft Wörter,
  keine Formatierung: Links steuern ihren Linktext bei, ihre URL nicht, Bilder gar nichts.
  Blöcke sind durch `\n` getrennt.
- Locale-Auflösung und Raum-Mapping verhalten sich exakt wie beim Detailendpunkt; fehlt die
  englische Fassung, bleibt der deutsche Text und `translationFallback` ist `true`.
- Höchstens **zwei** Strapi-Anfragen (kanonisch plus angeforderte Sprache), unabhängig von der
  Anzahl der Bereiche.

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
            "traits": ["vegan", "sprint"],
            "allergens": ["gluten", "gluten_wheat"],
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
- `traits` und `allergens` sind **stabile semantische Schlüssel**. Clients filtern ausschließlich
  darüber — **nie** über `markers[].code` oder `markers[].label`. Der Codenamensraum gehört der
  Quelle: er ist nirgends dokumentiert, mischt zwei Namensräume und darf sich jederzeit ändern.
  Details zur Zuordnung: [data-sources.md](data-sources.md).

  | Feld        | Werte                                                                                                                                                                                                                                                                                                                                         |
  | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
  | `traits`    | `vegetarian`, `vegan`, `meatless`, `sprint`                                                                                                                                                                                                                                                                                                   |
  | `allergens` | `gluten` (+ `gluten_wheat`, `gluten_rye`, `gluten_oats`, `gluten_barley`, `gluten_spelt`), `crustaceans`, `egg`, `peanuts`, `soy`, `milk`, `nuts` (+ `nuts_hazelnut`, `nuts_almond`, `nuts_walnut`, `nuts_cashew`, `nuts_pecan`, `nuts_pistachio`, `nuts_macadamia`), `celery`, `mustard`, `sesame`, `sulphites`, `lupin`, `molluscs`, `fish` |

  Ein Untertyp wird **immer** zusammen mit seiner Elternfacette ausgeliefert: Wer Gluten meidet,
  muss nicht wissen, dass `A1` Weizen bedeutet. Beide Arrays sind nach dieser Taxonomie sortiert,
  nicht nach der Reihenfolge der Quelle.

- Ein Marker, den die API **nicht** einordnen kann, bleibt in `markers` sichtbar und bekommt
  **keinen** erfundenen Schlüssel. `traits` und `allergens` sagen damit nur aus, was die Quelle
  tatsächlich erklärt hat.
- `sprint` stammt aus dem `is_sprint`-Feld des Planeintrags, nicht aus einem Marker-Code.
- `sourceLanguage: "de"` zeigt an, dass `name`, `subtitle`, `extras` und `markers[].label` aus der
  deutschsprachigen Quelle stammen und **nicht** übersetzt wurden.
- Ein Tag **ohne** Gerichte erscheint als leeres `meals`-Array — ein echter leerer Tag ist damit
  vom Ladefehler unterscheidbar.
- `dataStale` ist `true`, wenn `lastSuccessfulSyncAt` älter als `CANTEEN_STALE_AFTER_MINUTES` ist.
  `lastSuccessfulSyncAt: null` bedeutet: noch nie erfolgreich synchronisiert.

## 8. Stundenplan

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

## 9. Öffentliche Kalender

Quelle sind **öffentliche** Google-Kalender, die die Redaktion in Strapi freigibt. Der Worker lädt
deren **öffentlichen ICS-Feed** — siehe [public-calendars.md](public-calendars.md). Der Client
sieht **niemals** die Google-Kalender-ID, die Feed-URL, einen ETag oder das interne Feld
`ownerContact`.

Das Feature ist über `PUBLIC_CALENDAR_ENABLED` schaltbar und steht **standardmäßig auf `false`**.
Ausgeliefert werden ausschließlich Kalender, die aktiv **und** validiert sind **und** mindestens
einmal erfolgreich synchronisiert wurden.

### `GET /v1/calendars`

Der Katalog. Keine Parameter außer `locale`.

```jsonc
{
  "data": [
    {
      "id": "3d9a…", // Campus-UUID
      "slug": "stura-termine", // stabiler Bezeichner, Auswahlschlüssel der App
      "name": "StuRa-Termine",
      "description": null,
      "colorHex": "#5B3FD0",
      "iconKey": "calendar",
      "sortOrder": 10,
      "defaultSubscribed": true,
      "attribution": "Quelle: …", // oder null
      "dataState": "ready", // "ready" | "stale"
      "lastSuccessfulSyncAt": "2026-07-30T06:10:00.000Z",
      "dataStale": false,
      "googleOpenUrl": "https://calendar.google.com/…", // serverseitig konstruiert
    },
  ],
  "meta": {
    "requestedLocale": "de",
    "resolvedLocale": "de",
    "translationFallback": false,
    "featureEnabled": true,
  },
}
```

`defaultSubscribed` wertet die App **genau einmal** pro Slug aus — beim erstmaligen Auftauchen.
Ein Backend-Update überschreibt eine bewusste Abwahl nie. Dieselbe Regel wie bei News-Kanälen.

### `GET /v1/calendars/events`

Aggregierte Termine über **mehrere** ausgewählte Kalender.

| Parameter  | Typ          | Regeln                                                             |
| ---------- | ------------ | ------------------------------------------------------------------ |
| `calendar` | Slug         | **mehrfach** angebbar, ein Slug je Kalender; dedupliziert; max. 50 |
| `from`     | `YYYY-MM-DD` | optional, Standard heute                                           |
| `to`       | `YYYY-MM-DD` | optional, `to >= from`, Spanne max. **120 Tage** ⇒ sonst `400`     |
| `locale`   | `de` \| `en` |                                                                    |

**Eine leere Auswahl liefert eine leere Liste — niemals „alle Kalender“.** Das ist bewusst so: Ein
vergessener Parameter darf nicht stillschweigend alles ausliefern.

```jsonc
{
  "data": [
    {
      "id": "…",
      "calendarId": "3d9a…",
      "calendarSlug": "stura-termine", // damit die App Farbe und Name zuordnen kann
      "title": "Sitzung des Studierendenrats",
      "description": null, // nur bei showDescription, immer Plain Text
      "location": null, // nur bei showLocation, immer Plain Text
      "start": "2026-08-04T16:00:00.000Z",
      "end": "2026-08-04T18:00:00.000Z",
      "allDay": false,
      "status": "confirmed", // "confirmed" | "tentative" | "cancelled"
    },
  ],
  "meta": {
    "requestedLocale": "de",
    "resolvedLocale": "de",
    "translationFallback": false,
    "from": "2026-07-30",
    "to": "2026-11-27",
  },
}
```

Die Sortierung ist deterministisch. Wiederholungen sind bereits serverseitig zu einzelnen Terminen
expandiert; der Client kennt **keine** `RRULE`.

### `GET /v1/calendars/:slug/events`

Termine **eines** Kalenders. Parameter `from`, `to`, `locale` wie oben. Unbekannter oder nicht
auslieferbarer Slug ⇒ `404 PUBLIC_CALENDAR_NOT_FOUND`.

Die Antwort trägt zusätzlich `lastSuccessfulSyncAt` und `dataStale` in `meta`, damit die App den
Frischezustand genau dieses Kalenders anzeigen kann.

### `GET /v1/calendars/google-view-url`

| Parameter  | Typ  | Regeln                                                     |
| ---------- | ---- | ---------------------------------------------------------- |
| `calendar` | Slug | **erforderlich**, mehrfach angebbar, dedupliziert, max. 50 |

```jsonc
{
  "data": { "url": "https://calendar.google.com/calendar/embed?src=…&ctz=…" },
  "meta": { "requestedLocale": "de", "resolvedLocale": "de", "translationFallback": false },
}
```

Die URL wird **serverseitig** konstruiert (ein `src` je Kalender). Sie ist eine reine
**Ansicht** — es wird dabei nichts zum persönlichen Google-Konto der nutzenden Person hinzugefügt.
Stundenplan und Moodle sind keine Google-Quellen und niemals Teil dieser kombinierten Ansicht.

### Fehlercodes

| Code                        | Status                                                             |
| --------------------------- | ------------------------------------------------------------------ |
| `PUBLIC_CALENDAR_NOT_FOUND` | 404                                                                |
| `VALIDATION_FAILED`         | 400 (ungültiger Slug, ungültiges Datum, > 120 Tage, > 50 Kalender) |

## 10. Räume (Lageplan)

Der öffentliche Raumkatalog des **fiktiven** Demo-Lageplans. Die Kartengeometrie ist **nicht** Teil
dieser API — sie ist ein gebündeltes App-Asset (siehe [campus-map.md](campus-map.md)). Hier kommen
nur Bezeichnungen und redaktionelle Texte.

Ausgeliefert werden ausschließlich Räume mit `catalogActive=true` **und** `isVisible=true`.

### `GET /v1/rooms`

| Parameter     | Typ          | Regeln                   |
| ------------- | ------------ | ------------------------ |
| `buildingKey` | Slug         | optional, exakter Filter |
| `floorKey`    | Slug         | optional, exakter Filter |
| `locale`      | `de` \| `en` | wie überall              |

Der Katalog ist klein und wird vollständig ausgeliefert: Der Client cacht ihn und sucht **lokal**.
Es gibt bewusst **keine** serverseitige Volltextsuche.

```jsonc
{
  "data": [
    {
      "roomKey": "demo-north-level2-b201", // stabiler Bezeichner, auch der Deep-Link-Schlüssel
      "roomNumber": "B.201",
      "buildingKey": "demo-north",
      "buildingName": "Demogebäude Nord (fiktiv)", // lokalisiert
      "floorKey": "demo-north-level2",
      "floorLevel": 2,
      "floorName": "2. Obergeschoss", // lokalisiert
      "roomType": "lecture", // stabiler technischer Schlüssel, Label kommt aus der App
      "displayName": null, // optional, redaktionell, lokalisiert
      "description": null, // optional, redaktionell, lokalisiert
      "mapVersion": "demo-north-2026-07-31",
      "sortOrder": 10,
    },
  ],
  "meta": { "requestedLocale": "de", "resolvedLocale": "de", "translationFallback": false },
}
```

`roomType` ist eines von `lecture`, `seminar`, `office`, `lab`, `meeting`, `service`. Ein der App
unbekannter Wert wird dort auf eine neutrale Bezeichnung abgebildet und bricht nichts.

### `GET /v1/rooms/:roomKey`

Ein Raum. Unbekannter, unsichtbarer oder deaktivierter Schlüssel ⇒ `404 ROOM_NOT_FOUND`.

### Raumreferenzen in Kontakten

`GET /v1/contact-areas/:slug` liefert für den Bereich **und** für jede Person zusätzlich `rooms`:

```jsonc
{
  "rooms": [
    {
      "roomKey": "demo-north-level2-b201",
      "roomNumber": "B.201",
      "buildingKey": "demo-north",
      "buildingName": "Demogebäude Nord (fiktiv)",
      "floorKey": "demo-north-level2",
      "floorLevel": 2,
      "floorName": "2. Obergeschoss",
      "displayName": null,
    },
  ],
}
```

**Eine leere Liste ist der Normalfall** — ein Kontakt braucht keinen Raum, und die App rendert
dann gar nichts. Eine Raumreferenz enthält nie eine Strapi-ID.

### Fehlercodes

| Code                | Status                                    |
| ------------------- | ----------------------------------------- |
| `ROOM_NOT_FOUND`    | 404                                       |
| `VALIDATION_FAILED` | 400 (ungültiger `buildingKey`/`floorKey`) |

## 11. Was der Client garantiert nicht braucht

- keine Strapi-URL, kein Strapi-Token
- keine `location_id` und keine Kenntnis der Preisfeld-Nummerierung der Quelle
- keine WebUntis-URL, keinen WebUntis-Header, keine Schuljahres-ID, keine externe Gruppen-ID
- keine Google-Kalender-ID, keine ICS-Feed-URL, keinen ETag, kein `ownerContact`
- keine hartcodierte Kanal-, Mensa-, Bereichs-, Gruppen- oder Kalenderliste
- keine `RRULE`-Auswertung — Wiederholungen kommen bereits expandiert an
- keine Kartengeometrie: das SVG und die roomKey→Geometrie-Zuordnung sind gebündelte App-Assets

## 12. Nicht Teil dieser API

Die persönlichen Dienste **E-Mail**, **Noten** und **Moodle** laufen ausdrücklich **nicht** über
die Campus API. Die App spricht dafür direkt mit dem jeweiligen offiziellen Anbieter, damit weder
Campus API noch Strapi noch Worker Zugangsdaten oder persönliche Inhalte erhalten. Es gibt für sie
weder eine Route noch ein DTO noch eine Tabelle — siehe [architecture.md](architecture.md) §3.6 und
Grenzen G10–G12.
