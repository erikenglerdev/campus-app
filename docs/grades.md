# Noten (HIS-QIS-Notenspiegel)

Ein mobiler Bereich unter **Mehr → Noten**, der den persönlichen Notenspiegel **direkt vom
Gerät** aus dem HIS-QIS-Prüfungsportal der Hochschule Anhalt abruft. Es gibt bewusst
**keine** Backend-Beteiligung.

## Direkter Datenfluss — nicht verhandelbar

- Die App spricht **ausschließlich** und **direkt** mit `https://service.ssc.hs-anhalt.de`
  (HTTPS, Host-Allowlist). Login: `application/x-www-form-urlencoded`-POST mit den Feldern
  `asdf` (Benutzername) und `fdsa` (Passwort).
- **Kein** Umweg über Campus API, Strapi, CMS, Campus-Backend, Proxy, Analytics- oder
  Logging-Dienst. Weder Zugangsdaten noch Sitzungscookies, `asi`, Noten oder Prüfungsnamen
  verlassen das Gerät — außer über die direkte TLS-Verbindung zum offiziellen Portal.
- Dies ist eine **ausdrücklich beschlossene, eng begrenzte Ausnahme** von der Regel „Flutter
  spricht nur mit der Campus API" (siehe `CLAUDE.md`, § 2.1). Die zweite Ausnahme ist der
  Mailclient.

## Sicherheit

- **Nur HTTPS**, **nur** der Host `service.ssc.hs-anhalt.de`. Ein Redirect auf einen anderen
  Host oder auf HTTP wird abgebrochen (`tlsOrHostRejected`). Zertifikatsprüfung ist **nie**
  deaktiviert; es gibt **kein** „accept all certificates".
- Der dynamische `asi`-Parameter wird **aus den Links der aktuellen Sitzung** übernommen,
  **nie** fest einprogrammiert oder persistiert.
- Cookies und `asi` liegen **nur im Arbeitsspeicher** (In-Memory-Cookie-Jar, pro Abruf). Im
  `finally` wird der QIS-Logout aufgerufen und der Cookie-Jar geleert.
- **Nichts** wird geloggt: keine Zugangsdaten, Cookies, `asi` oder HTML. Fehler sind
  klassifizierte `GradeFailure`-Werte; `toString()` enthält nur die Kategorie.
- Zugangsdaten liegen **ausschließlich** im Keychain/Keystore (`flutter_secure_storage`),
  ohne unsicheren Fallback. Das Passwort wird **erst unmittelbar vor** einem Portalaufruf
  gelesen und **nie** dauerhaft im State/Controller gehalten. Der öffentliche Account-State
  enthält höchstens den Benutzernamen, **nie** das Passwort.

## Lokaler, verschlüsselter Notencache

- Die Noten werden in einer **verschlüsselten** Hive-CE-Box gespeichert
  (`campus_grades_cache_v1`), geöffnet mit einem zufälligen **256-Bit-AES-Schlüssel**
  (`Hive.generateSecureKey()`, CSPRNG). **Nur** dieser Schlüssel liegt im Keychain/Keystore.
- **Keine** Noten in einer unverschlüsselten Box oder als JSON in SharedPreferences.
- „Zugangsdaten und lokale Noten löschen" entfernt vollständig: Benutzername, Passwort,
  Cacheinhalt, Cache-Schlüssel, Synchronisationszeitpunkte, Sitzungsspuren und den State.
- Eine leere, ungültige oder fehlgeschlagene Portalantwort **überschreibt den letzten
  erfolgreichen Cache nie** — nur ein verifizierter Notenspiegel wird geschrieben.

## Synchronisation — 24-Stunden-Regel

- **Kein** Hintergrund-Polling, **kein** Timer, **kein** Backend-Cron.
- **Automatisch (lazy)** beim Öffnen des Bereichs: Der letzte **Versuch** und die letzte
  **erfolgreiche** Synchronisation werden **getrennt** gespeichert.
  - Kein Cache → nach der Einrichtung wird sofort synchronisiert (die Einrichtung selbst ist
    der erste Abruf).
  - Letzter Versuch **< 24 h** → **kein** automatischer Netzaufruf.
  - Letzter Versuch **≥ 24 h** → **genau ein** automatischer Versuch beim Öffnen.
  - Der Versuchszeitpunkt wird **vor** dem Netzaufruf gesetzt, damit ein Fehlversuch **nicht**
    bei jedem Widget-Build wiederholt wird.
  - Nur ein **Erfolg** ersetzt den Cache und aktualisiert `lastSuccessfulSync`.
- **Manuell** jederzeit: sichtbarer Aktualisieren-Button **und** Pull-to-refresh. Manuelle
  Synchronisation **umgeht** die 24-Stunden-Sperre. Während eines laufenden Abrufs wird kein
  zweiter gestartet (Single-Flight; parallele Auslöser werden zusammengeführt).
- Die UI zeigt transparent **„Zuletzt aktualisiert …"**. Bei einem Fehler bleibt der letzte
  erfolgreiche Stand sichtbar (Banner) und ein erneuter Versuch ist möglich.

## Bekannte Fragilität (inoffizielle HTML-Integration)

HIS-QIS bietet **keine** offizielle JSON-API; Login und Notenspiegel sind HTML. Die
Integration ist daher **inhärent fragil**:

- Der Parser identifiziert die Notenspiegel-Tabelle über die **erwarteten
  Spaltenüberschriften** (Prüfungsnummer, Prüfungstext, Note, Punkte, Status, Bonus, Versuch,
  Prüfungsdatum, Prüfer), **nicht** über CSS-Klassen oder eine feste Tabellen-ID.
- Ändert die Hochschule das Portal, wird die Struktur nicht erkannt → klassifizierter Fehler
  `portalStructureChanged`, verständliche lokalisierte Meldung, **kein** Überschreiben des
  Caches, **kein** Loggen der Antwort.
- **Vorgehen bei Portaländerungen:** die Header-Erkennung und ggf. den Navigationspfad in
  `qis_html_parser.dart` / `qis_grades_gateway.dart` anpassen, anonymisierte Fixtures unter
  `test/features/grades/grade_fixtures.dart` aktualisieren, Tests grün machen.
- **Vor einer Veröffentlichung** sollte möglichst eine **Abstimmung mit der Hochschule
  Anhalt** über die automatisierte Nutzung des Prüfungsportals erfolgen. Dies ist ein
  offenes Release-Gate.

## App-Switcher-Vorschau — offene Datenschutzentscheidung

Damit der Notenbildschirm nicht als lesbare Vorschau im App-Switcher erscheint, wäre auf
Android `FLAG_SECURE` (fensterglobal) und auf iOS ein Blur beim `resignActive` nötig. Eine
**saubere, plattformübergreifende, auf diesen einen Screen begrenzte** Lösung ohne
problematische globale Nebenwirkungen ist derzeit nicht verfügbar. Statt einer unsicheren
Scheinlösung bleibt dies eine **bewusst offene Entscheidung** — vor einer Veröffentlichung
zu klären.

## Schichten

```
features/grades/
  domain/         QisProfile (Host-Allowlist), GradeCredentials, Grade/GradeEntry/ExamStatus
                  (typsicher), GradeReport, GradeFailure, Clock, Ports (Gateway, CredentialStore,
                  CacheStore)
  data/           QisHtmlParser (DOM, kein Regex-HTML), QisGradesGateway (Dio + In-Memory-Cookies),
                  SecureGradeCredentialStore, EncryptedGradeCache (+ Codec)
  application/    Provider, GradeAccountController, GradesController (24h-Policy, Single-Flight)
  presentation/   Gate, Setup, Overview, Tile, Detail-Sheet, Fehler-Mapping
```

UI und Controller kennen **keine** Dio-, Cookie- oder HTML-Typen — alles liegt hinter
`GradesGateway`. Tests nutzen ausschließlich anonymisierte Fixtures, In-Memory-Fakes und einen
gescripteten HTTP-Adapter; **kein** Test kontaktiert das echte Portal.

## Automatisierte Tests

```bash
flutter test test/features/grades/
```

- `qis_html_parser_test.dart` — Header-Erkennung, deutsche Dezimalnoten, `0,0`+bestanden →
  unbenotet bestanden, leere Noten, Datum `dd.MM.yyyy`, Whitespace/Entities, unbekannte
  Status, fehlende Pflichtspalten → `portalStructureChanged`, keine Dedup.
- `qis_grades_gateway_test.dart` — form-urlencoded `asdf`/`fdsa`, HTTPS-Host-Allowlist,
  Redirect-Ablehnung (anderer Host / HTTP), Login-Erkennung (nicht nur HTTP 200), `asi` aus
  Session-Links, Logout auch bei Fehlern, keine Secrets/HTML in Fehlern.
- `grade_controller_test.dart` — Setup speichert erst nach Erfolg, kein Passwort im State,
  Secure-Storage-Fehler, Löschen wischt alles; 24h-Policy, Single-Flight, manueller Refresh,
  Fehler behält Cache, `lastSuccessfulSync` nur bei Erfolg.
- `grade_ui_test.dart` — „Noten" unter Mehr, Setup/Consent-Validierung, Anmeldung enthüllt
  Overview, Cache ohne Auto-Sync, Löschbestätigung.
