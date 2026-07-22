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

## 4. Nicht im MVP

**WebUntis / Stundenplan.** Bewusst ausgeschlossen: personenbezogene Anmeldung, unklare
Schnittstellenstabilität und rechtliche Klärung stehen aus. Die Architektur bleibt erweiterbar,
es wird aber **kein ungenutzter Code** dafür gebaut.
