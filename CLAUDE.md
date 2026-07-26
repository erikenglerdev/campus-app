# CLAUDE.md — Verbindliche Regeln für die Arbeit an diesem Repository

Projekt: **Campus Köthen App** · Lizenz: **AGPL-3.0-only** · `Copyright © 2026 Erik Engler and Jona Loreen Sommer`

Diese Datei ist für automatisierte und menschliche Beiträge gleichermaßen verbindlich.

---

## 1. Projektidentität — nicht verhandelbar

- Sichtbarer App-Name: **Campus Köthen**. Technische Kennung: `dev.erikengler.campuskoethen`.
- Das Projekt ist **unabhängig und inoffiziell**. Es darf an keiner Stelle den Eindruck einer
  offiziellen Anwendung der Hochschule Anhalt erwecken.
- **Verboten:** Logos, Wappen, geschützte Markenassets, kopierte Designsysteme der Hochschule;
  Formulierungen wie „offizielle App“, „HSA-App“ oder „von der Hochschule“.
- **Erlaubt:** sachliche Nennung von Hochschul- und Einrichtungsnamen zur Quellen- oder
  Bereichszuordnung.
- Der Unabhängigkeitshinweis muss in Deutsch **und** Englisch in README, `docs/product/mvp.md`,
  dem About-Screen und den rechtlichen Platzhalterseiten stehen. Kanonische Fassung:
  `apps/mobile/lib/l10n/app_de.arb` / `app_en.arb`, Schlüssel `aboutIndependenceNotice`.
- Der Studierendenrat der Hochschule Anhalt ist **vorgesehener**, nicht aktueller Betreiber.
  Er darf nirgends als bereits verantwortlicher Betreiber dargestellt werden.

## 2. Systemgrenzen — Architekturverstöße sind Blocker

1. Öffentliche, redaktionelle und allgemeine Campusdaten laufen **ausschließlich** über die
   Campus API unter `/v1`. Kein direkter Zugriff auf Strapi oder `meine-mensa.de` aus der App.

   **Eng begrenzte, ausdrücklich beschlossene Ausnahme (nur diese):** Persönliche, besonders
   sensible, nutzerauthentifizierte Dienste dürfen aus Datenschutzgründen **direkt** vom Gerät
   an den jeweiligen offiziellen Anbieter angebunden werden, damit weder Campus-Backend noch
   Strapi Zugangsdaten oder personenbezogene Inhalte erhalten. Aktuell sind das **genau drei**:
   - der **Studenten-Mailclient** → direkt zu `mail.hs-anhalt.de` (IMAPS/SMTP);
   - der **HIS-QIS-Notenspiegel** → direkt und **nur** zu `https://service.ssc.hs-anhalt.de`;
   - die **Moodle-Integration** (Kurse, Materialien, Aufgaben, Ankündigungen, Deadlines) →
     direkt und **nur** zu `https://moodle.hs-anhalt.de`. Kein Moodle-Token, keine Kurs-,
     Aufgaben-, Abgabe-, Ankündigungs- oder Deadline-Daten dürfen ein Campus-Köthen-Backend
     erreichen. Der quellenübergreifende Kalender führt Stundenplan (Campus API) und
     Moodle-Deadlines **ausschließlich lokal auf dem Gerät** zusammen.

   Für diese Ausnahmen gilt: **kein** Backend-Proxy, **keine** serverseitige Speicherung, **kein**
   Analytics-/Logging-Umweg. Zugangsdaten nur im Keychain/Keystore, sensible Inhalte nur
   verschlüsselt lokal. Dies ist **keine** allgemeine Erlaubnis für beliebige direkte
   Drittanbieterzugriffe — jede weitere Ausnahme muss hier ausdrücklich ergänzt werden.
2. Das Backend liest Strapi **ausschließlich** über dessen REST-API mit einem serverseitigen
   Read-only-Token. Kein direkter Zugriff auf Strapi-Tabellen, keine gemeinsame Prisma-Verbindung.
3. Redaktionelle Inhalte leben in Strapi. Importierte Mensadaten und Sync-Zustände leben in der
   operativen PostgreSQL-Datenbank. Getrennte Datenbanken, getrennte Rollen.
4. Die Strapi-Adresse ist **nie** eine Quellcode-Konstante — ausschließlich `STRAPI_BASE_URL`.
5. DEV und PROD unterscheiden sich **nur** durch Environment/Secrets, nie durch Quellcode.
6. Die Strapi Public Role erhält **keine** allgemeinen öffentlichen Leserechte.

## 3. Sicherheit

- **Niemals** reale Tokens, Passwörter, SSH-Schlüssel oder private Kontaktdaten in Code, Tests,
  Fixtures, Images, Commits, CI-Logs oder Dokumentation.
- `.env` ist ignoriert; gepflegt wird ausschließlich `.env.example` mit Platzhaltern.
- Strukturierte JSON-Logs ohne Secrets und ohne personenbezogene Debug-Dumps.
- CORS kommt aus dem Environment. Keine Wildcard in Produktionskonfiguration.
- PostgreSQL wird nie öffentlich gebunden.
- Container laufen als **non-root**.
- Kein automatisches Deployment, kein SSH aus CI, keine Server-Secrets im Repository.

## 4. Datenintegrität

- Externe Antworten werden **immer** explizit gegen ein Schema validiert (Zod), bevor sie
  verarbeitet werden.
- Eine leere, ungültige oder fehlgeschlagene Drittantwort **löscht niemals** den letzten
  erfolgreichen Datenbestand. Dieser Punkt ist durch Tests abgesichert.
- Geldwerte sind `Decimal`, niemals `float`.
- Upserts laufen über stabile Quell-IDs (`sourcePlanId`), nicht über zusammengesetzte Heuristiken.
- `food.image_url` wird **weder gespeichert noch ausgeliefert**. Es werden keine Mensabilder verwendet.

## 5. Inhalte und Urheberrecht

- Die Redaktion schreibt eigene Beiträge oder eigene Zusammenfassungen **mit Quellenlink**.
  Keine vollständige Übernahme fremder Texte.
- Nur eigene oder nachweislich freigegebene Bilder.
- Keine erfundenen Personen, Telefonnummern, E-Mail-Adressen oder offiziellen Aussagen — auch
  nicht in Seeds, Fixtures oder Tests. Demo-Daten werden **eindeutig als Demo markiert**.
- Fixtures aus Drittquellen werden anonymisiert.

## 6. Internationalisierung

- Unterstützte Locales: `de`, `en`. Standard und Fallback: `de`.
- Flutter: `gen_l10n` mit ARB-Dateien. **Keine sichtbaren UI-Texte im Dart-Code hardcodieren.**
- Strapi: offizielle i18n-Funktionen. Stabile Slugs/IDs laufen nicht pro Locale auseinander.
- Campus API: `locale=de|en`, optional `Accept-Language`. Antwort-Metadaten enthalten
  `requestedLocale`, `resolvedLocale` und `translationFallback`.
- **Externe Mensa-Gerichtsnamen werden niemals maschinell übersetzt.** Liefert die Quelle nur
  Deutsch, bleibt der Quelltext erhalten und wird transparent als Fallback markiert.
  API-eigene Labels (Mensanamen, Preisgruppen, Marker, Fehlertexte) sind zweisprachig.

## 7. Technische Standards

- TypeScript **strict**. Kein `any` ohne begründeten, kommentierten Ausnahmefall.
- Node.js 22.x. pnpm-Workspace mit Lockfile; `--frozen-lockfile` in CI.
- Öffentliche DTOs leaken **keine** Strapi-Internas (`data`, `attributes`, `documentId`,
  `populate`-Metadaten).
- Query-Parameter werden validiert und begrenzt (insbesondere `pageSize` und Datumsbereiche).
- Flutter: Riverpod, go_router, dio, `hive_ce` für den Inhaltscache.
  `SharedPreferences` **nur** für kleine skalare Einstellungen — kein JSON-Großspeicher.
- Design-Tokens sind zentral und typisiert. **Keine verstreuten Hexwerte in Screens.**

## 8. Arbeitsweise

- **TDD für fachlichen Code:** fehlschlagenden Test schreiben → Fehler real bestätigen →
  minimal implementieren → grün machen → refaktorieren.
- Kleine, verständliche Commits pro abgeschlossenem Arbeitsschritt.
- Keine Force-Pushes, kein Rebase veröffentlichter Historie.
- Nichts als erledigt melden, was nicht real ausgeführt und verifiziert wurde.
- Vor einem Push müssen alle lokal ausführbaren Gates aus dem README grün sein.

## 9. Barrierefreiheit

- Ausreichende Kontraste in Light **und** Dark Theme.
- Dynamische Schriftgrößen, Screenreader-Semantics, große Touch-Ziele (>= 48dp).
- Zustände werden **nie** ausschließlich über Farbe unterschieden.

## 10. Bekannte offene Entscheidungen (Release-Gates)

Diese Platzhalter dürfen nicht durch erfundene Werte ersetzt werden:

- Betreiberbestätigung · Impressum · Datenschutzerklärung · Support-Adresse
- Finales App-Icon · SMTP · Offsite-Backups · PROD-Server und Domains
