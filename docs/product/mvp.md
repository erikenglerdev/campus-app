# Campus Köthen — MVP-Definition

Stand: 22.07.2026 · Status: **in Entwicklung, nicht veröffentlicht**

---

## 0. Unabhängigkeitshinweis / Independence notice

**Deutsch**

> Campus Köthen ist eine unabhängige, inoffizielle Campus-App. Sie wird weder von der Hochschule
> Anhalt entwickelt oder betrieben noch von ihr offiziell unterstützt. Die Nennung der Hochschule
> und ihrer Einrichtungen dient ausschließlich der sachlichen Zuordnung öffentlich zugänglicher
> Informationen.

**English**

> Campus Köthen is an independent, unofficial campus app. It is neither developed nor operated by
> Hochschule Anhalt, nor is it officially endorsed by the university. The university and its
> institutions are named solely for the factual attribution of publicly available information.

Dieser Hinweis ist verbindlich und erscheint identisch in README, About-Screen und den rechtlichen
Platzhalterseiten der App.

---

## 1. Produktidentität

|                            |                                                                                                                 |
| -------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Projektname                | Campus Köthen App                                                                                               |
| Sichtbarer App-Name        | Campus Köthen                                                                                                   |
| Bundle-ID / Application ID | `dev.erikengler.campuskoethen`                                                                                  |
| Lizenz                     | `AGPL-3.0-only`                                                                                                 |
| Copyright                  | Copyright © 2026 Erik Engler and Jona Sommer                                                                    |
| Vorgesehener Betreiber     | Studierendenrat der Hochschule Anhalt — **noch nicht bestätigt**, daher aktuell nicht als Betreiber ausgewiesen |
| Sprachen                   | Deutsch (Standard/Fallback), Englisch                                                                           |

## 2. Zielgruppe und Nutzen

Studierende am Campus Köthen erhalten in einer App:

1. **News** aus mehreren, frei wählbaren redaktionellen Kanälen.
2. **Mensapläne** beider Köthener Mensen mit allen Preisgruppen.
3. **Kontakte** zu Anlaufstellen, funktional statt personenzentriert.

Die App funktioniert **ohne Nutzerkonto**. Alle Präferenzen bleiben auf dem Gerät.

## 3. Umfang

### 3.1 Enthalten

- News-Liste, News-Detail, dynamische News-Kanal-Auswahl
- Mensa-Auswahl und Speiseplan mit Tagesnavigation
- **Gruppenstundenplan** aus der öffentlichen WebUntis-Ansicht — vollständig umgesetzt, aber
  serverseitig über `WEBUNTIS_ENABLED` **standardmäßig deaktiviert**, bis die Nutzung
  organisatorisch freigegeben ist (siehe Release-Gates)
- Kontaktbereiche und Kontaktdetail
- Lokale Einstellungen: Sprache, Theme, Kanal-Abos, bevorzugte Mensa, gewählte Stundenplangruppe
- Offline-/Cache-Verhalten mit klarer Stale-Kennzeichnung
- About, Impressums-Platzhalter, Datenschutz-Platzhalter
- Deutsch und Englisch in App, CMS und API

### 3.2 Nicht enthalten

Nutzerkonten · Push-Nachrichten · persönlicher WebUntis-Login · Noten/Abwesenheiten/Hausaufgaben ·
Stundenpläne für Lehrpersonen oder Räume · Raumverfügbarkeit („freie Räume") ·
Zusammenführen mehrerer Gruppen in einen Plan · Gebäudepläne · Raumbelegung ·
Indoor-Navigation · Analytics/Tracking · Sentry oder externes Crash-Reporting · Redis · SMTP ·
automatisches Deployment · globale Volltextsuche

Die Architektur muss diese Erweiterungen ermöglichen, es wird dafür aber **kein ungenutzter Code**
gebaut.

## 4. Fachliche Anforderungen

### 4.1 News

- News entstehen ausschließlich in Strapi und werden über Draft & Publish veröffentlicht.
- Eine News kann mehreren Kanälen zugeordnet sein und erscheint dennoch **nur einmal** in der Liste.
- Startkanäle: `campus-news` („Campus News“) und `fb5-news` („FB5 News“), beide
  `defaultSubscribed = true`.
- Ein **neuer Kanal in Strapi erscheint ohne Flutter-Codeänderung** in der App.
- `defaultSubscribed` wird pro Kanal **genau einmal** ausgewertet — beim erstmaligen Auftauchen.
  Bewusst deaktivierte Kanäle bleiben deaktiviert, auch über App-Neustarts hinweg.
- Sind **alle** Kanäle deaktiviert, zeigt die App einen klaren Empty State und lädt **nicht**
  stillschweigend „alle News“.
- Inaktive Kanäle verschwinden aus der Auswahl, ohne gespeicherte Präferenzen zu beschädigen.
- Redaktionelle Regel: eigene Beiträge oder eigene Zusammenfassungen **mit Quellenlink**; keine
  Übernahme fremder Volltexte; nur eigene oder freigegebene Bilder.

### 4.2 Mensa

- Startmensen: `koethen-fasanerieallee` (Quelle `location_id=7`) und `koethen-lohmannstrasse`
  (Quelle `location_id=22`).
- Die Mensenliste kommt **ausschließlich** aus der Campus API. Flutter kennt keine Location-IDs.
  Eine weitere Mensa erfordert höchstens eine Backend-Konfigurationsänderung, **kein App-Release**.
- Angezeigt werden Datum, Name, Zusatztext, Beilagen, Sprint-Kennzeichen, Zutaten/Marker und
  **alle** verfügbaren Preisgruppen; der Studierendenpreis wird hervorgehoben.
- **Keine Mensabilder.** `food.image_url` wird weder gespeichert noch ausgeliefert.
- Der Worker synchronisiert alle zwei Stunden (`CANTEEN_SYNC_CRON="0 */2 * * *"`).
- Eine leere, ungültige oder fehlgeschlagene Quellantwort **löscht niemals** den letzten
  erfolgreichen Datenbestand.
- Die API liefert `lastSuccessfulSyncAt` und `dataStale`; die App zeigt beides verständlich an.
- Die App aktualisiert bei App-Start und App-Resume sowie zusätzlich **höchstens alle fünf Minuten**
  im Vordergrund. Im Hintergrund läuft **kein** Timer.

### 4.3 Kontakte

- Kontaktbereiche sind dynamische Strapi-Datensätze und werden ohne Codeänderung angelegt,
  sortiert, beschrieben und deaktiviert.
- Ein Bereich ist **auch ohne Kontaktperson vollständig gültig und nutzbar** (z. B. SSC,
  Studentenwerk als allgemeine Stelle).
- Eine Kontaktperson kann mehreren Bereichen zugeordnet sein.
- E-Mail, Telefon, Website und Terminlink werden über sichere Betriebssystemaktionen geöffnet.
- Fehlende Felder werden ausgeblendet statt als leere Zeile dargestellt.
- **Keine erfundenen Personen, Telefonnummern, E-Mail-Adressen oder offiziellen Aussagen.**
  Startdaten sind als Demo gekennzeichnet.

### 4.4 Sprachen

- Standard- und Fallback-Locale ist `de`.
- Die App folgt der Systemsprache und erlaubt eine manuelle Auswahl Deutsch/Englisch.
- Datum, Uhrzeit und Preise werden locale-gerecht formatiert.
- **Externe Mensa-Gerichtsnamen werden nie erfunden übersetzt.** Liefert die Quelle nur Deutsch,
  bleibt der Quelltext erhalten und wird als Fallback markiert (`translationFallback`).
  API-eigene Labels (Mensanamen, Preisgruppen, Marker, Fehlertexte) sind zweisprachig.

### 4.5 Offline und Cache

Lokal gespeichert werden:

| Daten                                        | Speicher                             |
| -------------------------------------------- | ------------------------------------ |
| Kanal-Abos, bevorzugte Mensa, Sprache, Theme | `SharedPreferences` (kleine Skalare) |
| Letzte News-Seite                            | `hive_ce`                            |
| Kanäle vollständig                           | `hive_ce`                            |
| Kontakte vollständig                         | `hive_ce`                            |
| Mensadaten aktuelle + kommende Woche         | `hive_ce`                            |

Gecachte Daten werden klar als offline bzw. veraltet gekennzeichnet. **Ein Cachefehler darf nie zum
App-Crash führen** — er degradiert auf einen Netzwerkabruf.

### 4.6 Barrierefreiheit

Ausreichende Kontraste in Light und Dark · dynamische Schriftgrößen · Screenreader-Semantics ·
Touch-Ziele >= 48dp · keine reine Farbcodierung · Light/Dark/System-Theme.

## 5. Akzeptanzkriterien

| #   | Kriterium                                                                                              |
| --- | ------------------------------------------------------------------------------------------------------ |
| A1  | Ein neuer Strapi-Kanal erscheint ohne Flutter-Codeänderung.                                            |
| A2  | Campus News und FB5 News sind unabhängig aktivierbar; beide standardmäßig abonniert.                   |
| A3  | Auswahl bleibt nach App-Neustart erhalten; neue Default-Kanäle überschreiben keine Nutzerentscheidung. |
| A4  | News in mehreren abonnierten Kanälen erscheint genau einmal.                                           |
| A5  | Entwürfe sind nicht öffentlich sichtbar.                                                               |
| A6  | Inaktiver Kanal verschwindet ohne App-Fehler.                                                          |
| A7  | Alle Kanäle deaktiviert ⇒ Empty State, kein Request für alle Kanäle.                                   |
| A8  | Beide Startmensen erscheinen über Backend-Daten; Flutter kennt keine Location-IDs.                     |
| A9  | Alle Preisgruppen werden angezeigt; keine Mensabilder.                                                 |
| A10 | Leere/ungültige Quellantwort löscht bestehende Mensadaten nicht.                                       |
| A11 | Wiederholter Import erzeugt keine Duplikate.                                                           |
| A12 | Neuer Kontaktbereich erscheint ohne Codeänderung; Bereich ohne Person funktioniert.                    |
| A13 | Inaktive Bereiche/Personen werden nicht ausgeliefert.                                                  |
| A14 | API leakt keine Strapi-Internas (`data`/`attributes`/`documentId`/`populate`).                         |
| A15 | Flutter spricht nur mit `/v1` der Campus API.                                                          |
| A16 | de/en sind in Flutter, Strapi und API real getestet.                                                   |
| A17 | Kein offizieller HSA-Eindruck, keine Hochschulassets; Unabhängigkeitshinweis sichtbar.                 |
| A18 | Keine Secrets im Repository oder in den Images.                                                        |
| A19 | Zwei getrennte Datenbanken mit getrennten Rollen.                                                      |
| A20 | Backend-, Strapi- und Flutter-Gates lokal grün.                                                        |

## 6. Offene Release-Gates

Diese Punkte blockieren eine Veröffentlichung und dürfen **nicht** durch erfundene Werte ersetzt
werden:

1. **Betreiberbestätigung** — Studierendenrat der Hochschule Anhalt organisatorisch bestätigen.
2. **Impressum** — aktuell bilinguale Platzhalterseite ohne Adressdaten.
3. **Datenschutzerklärung** — aktuell bilinguale Platzhalterseite.
4. **Support-Kontakt** — noch nicht festgelegt.
5. **Finales App-Icon** — aktuell neutraler eigener Platzhalter.
6. **SMTP** — für Strapi-Einladungen und Passwort-Reset.
7. **Offsite-Backups** — beide Datenbanken und Strapi-Uploads.
8. **PROD-Server und Domains.**
9. **Freigabe realer Kontaktdaten** und ggf. Personenfotos (Rechtsgrundlage).
10. **Nutzungsfreigabe der Mensa-Datenquelle** durch den Betreiber.
11. **Nutzungsfreigabe der WebUntis-Stundenplanquelle** — Erlaubnis zur automatisierten Nutzung
    der internen View-API, akzeptable Abrufrate, Stabilitätszusage beziehungsweise offizielle API,
    gewünschte Quellenangabe sowie zulässige Speicherung und Aufbewahrung von Lehrpersonennamen.
    Bis dahin bleibt `WEBUNTIS_ENABLED=false`.
