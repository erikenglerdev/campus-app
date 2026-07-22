# Datenquellen

Campus Köthen App · `AGPL-3.0-only`

---

## 1. Übersicht

| Quelle                          | Art                            | Verbraucher   | Im MVP   |
| ------------------------------- | ------------------------------ | ------------- | -------- |
| Strapi 5 (eigene Instanz)       | REST, Read-only-Token          | Campus API    | ja       |
| `meine-mensa.de/api/food_plans` | öffentliche REST-Schnittstelle | Campus Worker | ja       |
| WebUntis                        | —                              | —             | **nein** |

Der Flutter-Client greift auf **keine** dieser Quellen direkt zu (siehe
[architecture.md](architecture.md), Grenze G1).

---

## 2. Strapi

Basis-URL ausschließlich über `STRAPI_BASE_URL`. Authentifizierung über `STRAPI_API_TOKEN` als
Bearer-Token mit **Read-only-Scope**.

Genutzte Endpunkte:

```http
GET /api/news-channels?locale=<de|en>&populate=...
GET /api/news-articles?locale=<de|en>&populate=...
GET /api/contact-areas?locale=<de|en>&populate=...
```

Regeln:

- Es werden nur **veröffentlichte** Einträge gelesen (Strapi 5 Standard ohne `status=draft`).
- Die Public Role erhält keine Leserechte; ohne gültigen Token liefert Strapi `403`.
- Strapi-Antwortstrukturen (`data`, `attributes`, `documentId`, `meta.pagination`) werden im
  Backend gemappt und **nie** nach außen durchgereicht.

---

## 3. meine-mensa.de

### 3.1 Endpunkt

```http
GET https://meine-mensa.de/api/food_plans?location_id=<id>&date_from=<YYYY-MM-DD>&date_to=<YYYY-MM-DD>
```

Betreiber: Studentenwerk Halle. Kein Token erforderlich. Antwort ist `application/json`.

### 3.2 Verifizierte Standorte

| `location_id` | Slug                     | Anzeigename         | Campus-Label   |
| ------------- | ------------------------ | ------------------- | -------------- |
| `7`           | `koethen-fasanerieallee` | Mensa Köthen        | Fasanerieallee |
| `22`          | `koethen-lohmannstrasse` | Mensa Lohmannstraße | Lohmannstraße  |

Diese Zuordnung ist **Backend-Konfiguration** (`apps/backend/src/modules/canteen/canteens.config.ts`).
Flutter kennt keine Location-IDs. Eine weitere Mensa erfordert kein App-Release.

### 3.3 Verifizierte Antwortstruktur

Am 22.07.2026 real gegen beide Standorte geprüft (HTTP 200):

```jsonc
{
  "data": [
    {
      "id": 58033, // stabile Plan-ID → Upsert-Schlüssel (sourcePlanId)
      "date": "2026-07-20", // YYYY-MM-DD
      "counter_id": 44, // Ausgabetheke
      "location_id": 7, // MUSS gegen die angefragte Mensa geprüft werden
      "is_sprint": true,
      "food": {
        "id": 1892, // sourceFoodId
        "name": "Bulgur-Pfanne",
        "name_2": "mit Kichererbsen, Wirsing und Kräuterdip",
        "ingredients": ["2", "52", "53", "A1", "A3", "G2"],
        "price_1": 1.95, // Studierende
        "price_2": 4.95, // Bedienstete
        "price_3": 7, // Gäste  ← kann Integer sein, nicht nur Dezimal
        "extra_1": "",
        "extra_2": "",
        "extra_3": "",
        "extra_4": "",
        "image_url": "https://…", // WIRD NICHT GESPEICHERT UND NICHT AUSGELIEFERT
      },
    },
  ],
  "meta": {
    "ingredients": { "2": "Konservierungsstoffe", "52": "vegan", "A1": "enthält Weizengluten" },
    "markers": { "53": "Sprint-Menü", "54": "Mensa Vital", "55": "Bio", "9901": "Klima-Teller" },
  },
}
```

### 3.4 Beobachtete Eigenheiten

Diese Punkte sind der Grund für die strikte Schema-Validierung:

1. **`food.ingredients` mischt zwei Namensräume.** Die Liste enthält sowohl Codes aus
   `meta.ingredients` als auch aus `meta.markers` (im Beispiel ist `"53"` = „Sprint-Menü“ ein
   Marker). Die Auflösung muss beide Wörterbücher konsultieren und den `kind` festhalten.
2. **Codes sind Strings, keine Zahlen** — auch die rein numerischen (`"52"`). Es gibt zusätzlich
   alphanumerische Codes (`"A1"`, `"G2"`) und Codes mit Sonderzeichen (`"A!"`, `"G!"`).
3. **Preise kommen als JSON-Zahl mit unterschiedlicher Genauigkeit** (`7` statt `7.00`). Sie werden
   als `Decimal` gespeichert, nie als `float`.
4. **Labels liegen ausschließlich auf Deutsch vor.** Sie werden **nicht** maschinell übersetzt.
   Bei `locale=en` bleibt der deutsche Quelltext erhalten und wird als `translationFallback`
   markiert.
5. **Die Antwort kann sehr klein sein.** Location 22 lieferte im geprüften Zeitraum genau einen
   Eintrag. Eine kleine Antwort ist **kein** Fehlersignal — eine leere Antwort löscht trotzdem
   niemals bestehende Daten.
6. `extra_1` bis `extra_4` sind häufig leere Strings und werden vor dem Speichern gefiltert.

### 3.5 Preisgruppen

| Feld      | Slug       | Label DE    | Label EN  |
| --------- | ---------- | ----------- | --------- |
| `price_1` | `student`  | Studierende | Students  |
| `price_2` | `employee` | Bedienstete | Employees |
| `price_3` | `guest`    | Gäste       | Guests    |

**Alle** verfügbaren Preisgruppen werden gespeichert und ausgeliefert. Die Zuordnung
Feld → Bedeutung ist Backend-Wissen; die Labels sind API-eigene, zweisprachige Texte.
Der Studierendenpreis wird in der App hervorgehoben.

### 3.6 Abrufregeln

| Regel             | Wert                                                                                        |
| ----------------- | ------------------------------------------------------------------------------------------- |
| Intervall         | alle 2 Stunden (`CANTEEN_SYNC_CRON="0 */2 * * *"`)                                          |
| Zeitraum je Abruf | aktuelle + kommende Woche                                                                   |
| Timeout           | `CANTEEN_HTTP_TIMEOUT_MS`, Standard 15000                                                   |
| Retry             | 3 Versuche, exponentieller Backoff                                                          |
| Manueller Sync    | administratives CLI-Kommando — **kein** öffentlicher Sync-Endpunkt                          |
| Tests             | ausschließlich gegen anonymisierte Fixtures unter `apps/backend/test/fixtures/meine-mensa/` |

### 3.7 Rechtliches

- Daten werden inhaltlich unverändert übernommen und der Quelle zugeordnet.
- **Keine Mensabilder.** `food.image_url` wird nicht persistiert und nicht ausgeliefert.
- Preise und Allergenangaben sind Angaben der Quelle ohne Gewähr; die App weist darauf hin.
- Eine abschließende Nutzungsfreigabe durch den Betreiber ist ein offenes Release-Gate.

---

## 4. WebUntis — öffentliche Stundenplanansicht

> ⚠️ **Kein offizieller Vertrag.** Genutzt wird die **interne View-API** der öffentlichen
> WebUntis-Weboberfläche. Sie ist nicht dokumentiert, nicht versioniert und kann sich jederzeit
> ohne Ankündigung ändern. Ein Parserfehler ist deshalb zuerst als Änderung der Quelle zu
> behandeln, nicht als Bug im eigenen Code.

Beobachtet und verifiziert am **22.07.2026**.

### 4.1 Endpunkte

Basis: `https://hsa.webuntis.com/WebUntis/api/rest/view/v1`

| Endpunkt             | Methode | Pflichtparameter                                                | Pflicht-Header                             |
| -------------------- | ------- | --------------------------------------------------------------- | ------------------------------------------ |
| `/app/data`          | GET     | —                                                               | `anonymous-school: hsa`                    |
| `/timetable/filter`  | GET     | `resourceType=CLASS`                                            | zusätzlich `X-Webuntis-Api-School-Year-Id` |
| `/timetable/entries` | GET     | `start`, `end` (`YYYY-MM-DD`), `format=2`, `resourceType=CLASS` | zusätzlich `X-Webuntis-Api-School-Year-Id` |

Die Schuljahres-ID ist **dynamisch** und wird zur Laufzeit aus `/app/data` gelesen. Sie ist
nirgends im Quellcode hinterlegt.

### 4.2 Beobachtete Eigenheiten

1. **Ein fehlender Pflichtparameter liefert HTTP 500**, nicht 400, mit dem Parameternamen im
   JSON-Body. Der Status allein ist hier also ein schlechtes Fehlersignal.
2. **`entries` ohne Ressourcen-IDs liefert alle Klassen auf einmal.** Gemessen: 270 Klassen ×
   5 Tage = 1350 Tagesobjekte, ~505 KB, ~1,2 s. Genau deshalb ist die Synchronisation ein
   **Batch pro Zeitfenster** und keine 270 Einzelabrufe.
3. **`position1` … `position7` haben keine feste Bedeutung.** Allein in der aufgezeichneten Stichprobe
   erschien `ROOM` auf Position 2 und 3, `CLASS` auf 3 und 4, `SUBJECT` auf 1 und 2. Ausgewertet wird
   deshalb ausschließlich über `current.type` — eine indexbasierte Auswertung würde Räume still als
   Klassen einsortieren.
4. `duration.start`/`duration.end` sind **lokale Wandzeit ohne Zone** und werden als
   `Europe/Berlin` interpretiert. Beim Import wird in absolute UTC-Zeitpunkte umgerechnet.
5. `ids[]` ist der stabile Quellschlüssel und enthält gelegentlich mehr als einen Wert.
6. Beobachtetes Vokabular — **was gesehen wurde, nicht was existiert**:
   `type` = `NORMAL_TEACHING_PERIOD`, `ADDITIONAL_PERIOD`;
   `status` = `REGULAR`, `CHANGED`, `CANCELLED`, `ADDITIONAL`.
   Unbekannte Werte werden auf `unknown` abgebildet und brechen den Import nicht.

### 4.3 Abrufregeln

| Regel           | Wert                                                                                  |
| --------------- | ------------------------------------------------------------------------------------- |
| Feature-Flag    | `WEBUNTIS_ENABLED`, **Default `false`**                                               |
| Gruppenkatalog  | täglich (`WEBUNTIS_GROUP_SYNC_CRON`, Default `0 3,15 * * *`)                          |
| Stundenplan     | alle 30 Minuten (`WEBUNTIS_ENTRY_SYNC_CRON`), **ein** Request pro Lauf                |
| Zeitfenster     | 7 Tage zurück, 28 Tage voraus (konfigurierbar)                                        |
| API-Zeitraum    | maximal 42 Tage                                                                       |
| Timeout / Retry | 20 s, 3 Versuche, Backoff mit Jitter, `Retry-After` wird beachtet                     |
| Abstand         | 1,5 s zwischen Fremdrequests                                                          |
| Tests           | ausschließlich gegen redigierte Fixtures unter `apps/backend/test/fixtures/webuntis/` |

Die App ruft WebUntis **nie** direkt auf. Kein Client-Request löst einen Fremdabruf aus.

### 4.4 Personenbezogene Daten

Die Quelle liefert **Lehrpersonennamen**. Diese werden gespeichert und angezeigt, weil sie
Bestandteil des öffentlich einsehbaren Stundenplans sind. In den committeten Fixtures sind sie
durch deterministische Pseudonyme ersetzt — die Live-Antwort enthielt 145 echte Namensvarianten,
keine davon liegt im Repository.

**Offen und vor einer Produktivfreigabe zu klären:**

- Erlaubnis zur automatisierten Nutzung der internen View-API
- akzeptable Abrufrate
- Zusage zur Schnittstellenstabilität beziehungsweise eine offizielle API
- gewünschte Quellenangabe
- zulässige Speicherung und Anzeige von Lehrpersonennamen sowie Aufbewahrungsfristen

Bis dahin bleibt `WEBUNTIS_ENABLED=false`.

---

## 5. Nicht im MVP

Stundenpläne für **Lehrpersonen oder Räume**, Raumverfügbarkeit („freie Räume"), persönlicher
WebUntis-Login, Noten, Abwesenheiten und Hausaufgaben. Die öffentliche Ansicht wird ausschließlich
für **Gruppenstundenpläne** genutzt.
