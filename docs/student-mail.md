# Studentische E-Mail (IMAP/SMTP)

Ein minimaler E-Mail-Client, der sich **direkt vom Gerät** mit dem Mailserver der
Hochschule Anhalt verbindet. Es gibt bewusst **keinen** serverseitigen Mail-Proxy.

## Architektur — nicht verhandelbar

- Die App verbindet sich **direkt** mit `mail.hs-anhalt.de`:
  - **IMAP** über `993` mit implizitem TLS (kein Fallback auf `143`/Klartext).
  - **SMTP-Submission** über `587` mit **verpflichtendem STARTTLS** (kein Fallback auf
    `25`/`465`/Klartext; Abbruch, wenn der Server STARTTLS nicht anbietet).
- Zertifikats- **und** Hostname-Prüfung sind aktiv. `allowBadCertificates` wird
  **nirgends** verwendet. Kein Certificate-Pinning.
- Die Campus-Köthen-API, Strapi und der Worker sind **nie** an Mail beteiligt. Sie
  erhalten **weder Zugangsdaten noch E-Mails**.
- Genau **zwei** Eingaben: E-Mail-Adresse + Passwort. Die Adresse ist zugleich
  IMAP-Benutzername, SMTP-Benutzername und Absender. Es gibt **kein** separates Feld
  für Matrikelnummer, Benutzername, Login, Absender oder Domain.

## Sicherheit

- Passwort und Adresse liegen **ausschließlich** im geräteeigenen sicheren Speicher
  (`flutter_secure_storage`, iOS Keychain / Android Keystore). **Nie** in
  `SharedPreferences` oder Hive. Kein unsicherer Fallback: Ist der sichere Speicher nicht
  verfügbar, wird **nicht** gespeichert und ein klarer Fehler gezeigt.
- Das Passwort erscheint **nie** in Logs, Exceptions, Telemetrie, `toString()` oder
  Debug-Ausgaben. Das Protokoll-Debugging von `enough_mail` ist **aus**
  (`isLogEnabled: false`).
- E-Mail-Inhalte werden **nicht dauerhaft** gespeichert; der bestehende Hive-Cache wird
  für Mail **nicht** genutzt.
- HTML-Mails werden zu **reinem Text** reduziert. Kein WebView, kein JavaScript, **keine**
  automatische Nachladung entfernter Bilder. Links laufen nur über den bestehenden
  sicheren URL-Launcher (`https`/`mailto`/`tel`).
- Verbindungen werden bei `dispose`/Account-Entfernen geschlossen. „Account entfernen“
  löscht Adresse und Passwort vollständig aus dem sicheren Speicher.

## Schichten

```
features/mail/
  domain/         Reine Modelle + Ports: MailGateway, MailCredentialStore,
                  MailCredentials, MailMessage*, MailFailure, HsaMailProfile
  data/           Adapter: EnoughMailGateway (kapselt enough_mail vollständig),
                  SecureMailCredentialStore, html_to_text
  application/    Riverpod-Controller: Account, Inbox, Compose, Provider
  presentation/   Screens: Setup, Inbox, Message, Compose + Fehler-Mapping
```

Die UI und die Riverpod-Controller kennen **keine** `enough_mail`-Typen — die Bibliothek
liegt vollständig hinter `MailGateway`. Tests nutzen ausschließlich In-Memory-Fakes
(`FakeMailGateway`, `InMemoryMailCredentialStore`) und verbinden sich **nie** mit dem
echten Server.

## Automatisierte Tests

```bash
flutter test test/features/mail/
```

- `mail_domain_test.dart` — Profil-Endpunkte, Credentials-Redaction, E-Mail-Validierung.
- `mail_controller_test.dart` — Anmelden/Abmelden, Inbox-Laden, typisierte Fehler,
  Doppel-Send-Schutz, Sent-Kopie-Ergebnis.
- `mail_ui_test.dart` — Gate (Setup ↔ Inbox), Anmeldeformular-Validierung, Account
  entfernen, Nachricht anzeigen (+ als gelesen markieren), Verfassen/Senden.

## Manuelle Testcheckliste (echter Server, echtes Konto)

> Nie echte Zugangsdaten in Code, Tests, Fixtures oder Commits ablegen. Diese Liste wird
> mit einem **persönlichen** Hochschulkonto auf einem Gerät durchgeführt.

Einrichtung / Sicherheit

- [ ] Setup-Screen zeigt Unabhängigkeitshinweis, Erklärung der Direktverbindung, den
      Hinweis, dass Campus-Server keine Zugangsdaten/Mails erhalten, und den externen Link
      auf `https://mail.hs-anhalt.de/`.
- [ ] Anmeldung mit korrekten Daten führt in den Posteingang.
- [ ] Falsches Passwort → verständliche Fehlermeldung, **keine** rohen Serverdaten,
      **kein** Speichern.
- [ ] Ungültige Adresse → lokale Validierung, Server wird **nicht** kontaktiert.
- [ ] Nach „Account entfernen“ ist wieder der Setup-Screen sichtbar; erneuter App-Start
      landet im Setup (Zugangsdaten wirklich gelöscht).

Posteingang / Detail

- [ ] Es werden bis zu 50 aktuelle Nachrichten des gewählten Ordners (neueste zuerst)
      angezeigt.
- [ ] Ungelesene sind nicht nur über Farbe erkennbar (Icon/Fettung).
- [ ] Öffnen einer Nachricht zeigt reinen Text; sie wird als gelesen markiert.
- [ ] HTML-Mail wird als Text dargestellt; entfernte Bilder werden **nicht** geladen.
- [ ] Mail mit Anhang zeigt die Anhänge: Bilder als Inline-Vorschau (aus dem Speicher,
      kein Netzwerkabruf, keine Datei geschrieben), andere Typen als Kachel mit Name,
      Typ und Größe.
- [ ] Flugmodus → Aktualisieren zeigt einen Fehler mit „Erneut versuchen“, kein Absturz.

Ordner

- [ ] Das Ordner-Symbol öffnet die Liste **aller** Server-Ordner (IMAP LIST); ein
      Sonderordner (Gesendet/Entwürfe/Papierkorb/Spam/Archiv) trägt Symbol und
      lokalisierten Namen.
- [ ] Auswahl eines Ordners lädt dessen Nachrichten; der Titel zeigt den Ordnernamen.
- [ ] Öffnen einer Nachricht in einem anderen Ordner liest aus **diesem** Ordner.

Verfassen / Senden

- [ ] „Von” ist die eigene Kontoadresse (nicht editierbar); ist beim Einrichten ein
      Anzeigename gesetzt, sehen Empfänger `”Name” <adresse>`.
- [ ] Senden an eine gültige Adresse: die App kehrt **sofort** nach dem SMTP-Versand
      zum Posteingang zurück (kein Verweilen im Sende-Screen); die Kopie im Ordner
      „Gesendet” wird im Hintergrund abgelegt, ein Hinweis erscheint nur, wenn das
      nicht klappt.
- [ ] Mehrere Empfänger in „An”/„Cc” mit Komma getrennt werden alle adressiert.
- [ ] Schnelles Doppeltippen auf „Senden” verschickt **nur einmal**.
- [ ] Ungültiger Empfänger → Validierung, kein Sendeversuch.

Antworten

- [ ] „Antworten” öffnet den Verfassen-Screen mit dem Absender als Empfänger,
      „Re: …”-Betreff und zitiertem Originaltext.
- [ ] „Allen antworten” adressiert zusätzlich alle ursprünglichen Empfänger (Cc),
      **ohne** die eigene Adresse.

Barrierefreiheit / i18n

- [ ] Deutsch und Englisch: alle neuen Texte übersetzt, keine hartkodierten Strings.
- [ ] Ausreichende Kontraste in Light **und** Dark Theme.
- [ ] Touch-Ziele ≥ 48 dp; doppelte Schriftgröße ohne Überlauf.

## Bekannte Grenzen (bewusst)

Kein Hintergrund-Sync, kein IMAP IDLE, kein Verschieben/Löschen, keine Ordnerverwaltung
(nur Lesen/Wechseln, kein Anlegen/Umbenennen), keine mehrfachen Konten. Anhänge werden
**angezeigt** (Bilder inline, sonst Metadaten), aber nicht auf das Gerät gespeichert oder
mit anderen Apps geöffnet. Der MVP liest, öffnet, beantwortet und schreibt reinen Text.
