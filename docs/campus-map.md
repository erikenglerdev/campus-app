<!-- Campus Köthen App · AGPL-3.0-only · Copyright © 2026 Erik Engler and Jona Loreen Sommer -->

# Lageplan, Raumkatalog und CMS-Raumsync

Lageplan mit Gebäude- und Etagenauswahl sowie Raumsuche unter „Mehr → Lageplan“. Die Geometrie
ist ein selbst erstelltes, versioniertes Asset im Repository; Raumbezeichnungen und redaktionelle
Texte kommen über die Campus API und werden offline gecacht.

Zwei Kartengebäude, bewusst unterschiedlicher Natur:

| Gebäude                   | `buildingKey`             | Ebene                           | Räume |
| ------------------------- | ------------------------- | ------------------------------- | ----- |
| Demogebäude Nord (fiktiv) | `demo-north`              | `demo-north-level2`             | 30    |
| Campus Köthen – Übersicht | `koethen-campus-overview` | `koethen-campus-overview-level` | 0     |

> ⚠️ **Das Demogebäude ist vollständig erfunden.** Etage und alle 30 Räume (B.201–B.230) sind
> Demonstrationsdaten; es wird kein realer Grundriss und kein realer Raum dargestellt.
>
> ⚠️ **Die Campusübersicht ist schematisch.** Sie ist vereinfacht, nicht maßstabsgetreu und
> **kein** Flucht-, Rettungs- oder amtlicher Lageplan. Sie enthält **keine** Räume und **keine**
> Innengeometrie. Vor einer Veröffentlichung sind Herkunft und Rechte an der zugrunde liegenden
> Vorlage zu klären — siehe [§8](#8-release-gate-reale-gebäudepläne).

Welche Aussage die App trifft, steht als `planKind` (`fictional` | `schematic`) **im Katalog**,
nicht im Widget: Das Badge über der Karte folgt dem Gebäude, damit ein neues Gebäude niemals
stillschweigend die falsche Behauptung erbt.

## 1. Datenfluss

```
packages/campus-map/                    ── kanonische Quellen (im Repository)
  buildings/demo-north/level2.svg          Geometrie (Etagenplan)
  campus/koethen-overview.svg              Geometrie (Campusübersicht)
  catalog/campus-map.catalog.json          strukturierte technische Wahrheit
        │
        │  validate + generate (deterministisch, dependency-frei)
        ├────────────────────────────▶ apps/mobile/assets/maps/    (gebündelt in der App)
        │                                map_catalog.json · demo-north/level2.svg
        │                                campus/koethen-overview.svg
        │
        └── rooms:sync ──▶ Strapi (room)  ──▶ Campus API /v1/rooms ──▶ Flutter
                            technische Felder      nur catalogActive
                            + redaktionelle Felder  UND isVisible
```

Zwei getrennte Wege, bewusst:

- **Geometrie** wird **nie** über das Netz geladen. Sie ist Teil des App-Bundles, funktioniert
  offline und erzeugt keinen einzigen Drittanbieter-Request.
- **Bezeichnungen und redaktionelle Texte** laufen über die Campus API, damit DE/EN, Sichtbarkeit
  und Redaktion ohne App-Release änderbar bleiben.

Die App spricht ausschließlich mit `/v1`. Es gibt **keinen** Strapi-Zugriff und **keinen**
Schreibweg aus der App ins CMS.

## 2. Kanonische Quellen

| Datei                             | Rolle                                                     |
| --------------------------------- | --------------------------------------------------------- |
| `buildings/demo-north/level2.svg` | Geometriequelle: Wände, Flure, Türen, 30 Raumrechtecke    |
| `campus/koethen-overview.svg`     | Geometriequelle: 21 Gebäudegruppen, Wege, Grün, Symbole   |
| `catalog/campus-map.catalog.json` | strukturierte Quelle: Schlüssel, Typen, Fokus, Sortierung |

Der Katalog enthält `schemaVersion`, `mapVersion`, Gebäude (lokalisierte Namen DE/EN), Etagen
(`level`, `viewBox`, `svgPath`, `expectedRoomCount`) und Räume (`roomKey`, `roomNumber`,
`roomType`, `svgElementId`, `focus`, `bounds`, `sortOrder`).

Jedes Raumelement im SVG trägt `id`, `data-room-key`, `data-room-number`, `data-building-key`,
`data-floor-key` sowie `data-focus-x`/`data-focus-y`. Beide Quellen müssen exakt übereinstimmen.

**`roomType`** ist ein stabiles technisches Enum: `lecture`, `seminar`, `office`, `lab`, `meeting`,
`service`. Die Beschriftung passiert ausschließlich in der Flutter-l10n — so kann eine neue Kategorie
nie einen untranslatierten deutschen Begriff in die App tragen.

## 3. Validator und Generator

```bash
pnpm --filter @campus/map validate   # nur prüfen
pnpm --filter @campus/map generate   # App-Assets neu schreiben
pnpm --filter @campus/map check      # prüfen UND Drift melden (das CI-Gate)
pnpm --filter @campus/map test       # 52 Tests
```

Geprüft wird unter anderem: gültiges XML · genau `expectedRoomCount` eindeutige `roomKey`s ·
jeder Katalograum hat genau ein SVG-Element · jedes SVG-Raumelement ist im Katalog · `roomKey`,
SVG-`id` und `data-room-key` stimmen überein · Gebäude- und Etagenreferenzen existieren ·
`viewBox` im Katalog entspricht dem SVG · Fokus **und** Bounds liegen im `viewBox` · keine
Scripts, `foreignObject`, externen Ressourcen, `href`s, eingebetteten Bilder oder unsicheren URLs.

Der SVG-Reader ist eine **Allowlist**: DOCTYPE, CDATA und Processing Instructions werden
abgelehnt, ebenso alles andere, was er nicht ausdrücklich versteht. Damit existiert die
Entity-Expansion-Angriffsfläche gar nicht erst. Er ist bewusst dependency-frei, wie
`packages/openapi`.

Die Generierung ist **rein**: Alle Dateien entstehen zuerst im Speicher, geschrieben wird erst nach
vollständigem Erfolg. Eine ungültige Eingabe hinterlässt daher **keine** halb erzeugten Dateien.

### 3.1 Warum das mobile SVG nicht das kanonische ist

Zwei Gründe, beide durch Tests abgesichert:

1. **Sprache.** Die kanonischen Zeichnungen enthalten deutsche Überschriften, eine deutsche Legende
   und deutsche Beschriftungen („Hörsaal“, „Treppe West“, „Aufzug“, „Mensa“, „KITA“,
   „Richtung City“). Sie würden die DE/EN-Regel unterlaufen. Im generierten Asset überleben nur
   sprachneutrale Beschriftungen; alles andere rendert Flutter aus der l10n. Die Auswahl erfolgt
   über eine **Allowlist** von Textklassen — ein Denylist-Ansatz hatte beim ersten unbekannten
   Klassennamen prompt deutschen Text durchgelassen:

   | Klasse        | überlebt                                                           |
   | ------------- | ------------------------------------------------------------------ |
   | `room-number` | Raumnummern des Etagenplans (`B.201`)                              |
   | `map-label`   | Gebäudecodes (`01`, `W VII`, `TZK`), Straßennamen, Maßstabsangaben |

   Die Campusübersicht verliert dadurch bewusst die Beschriftungen „Mensa“, „KITA“ und
   „Richtung City“: Es sind Gattungsbegriffe mit englischer Entsprechung, keine sprachneutralen
   Codes. `data-building-number` trägt sie weiterhin als **Metadaten**, die nichts zeichnen.

2. **Renderer.** `flutter_svg` unterstützt **keine** `<style>`-Blöcke (`unhandled element <style/>`)
   und verwirft die gesamte Stylesheet — jeder Raum wäre ungestylt. Der Generator löst die
   CSS-Klassenregeln deshalb in Präsentationsattribute auf. `<marker>` und `marker-*` werden
   ebenfalls entfernt, weil der Renderer sie ignoriert. Ein Widget-Test rendert die gebündelten
   Assets und schlägt fehl, sobald wieder eine nicht unterstützte Konstruktion auftaucht.

   `<defs>` mit lokalen `<use xlink:href="#id">`-Fragmenten bleiben dagegen **erhalten**: Die
   Campusübersicht zeichnet Bäume, Parkplätze und Sammelpunkte darüber. Dass der Renderer sie
   wirklich malt, prüft ein Test, der das Ergebnis **rastert** und mit derselben Zeichnung ohne
   `<use>` vergleicht — ein ignoriertes `<use>` würde weder eine Warnung noch eine Exception
   erzeugen, die Karte wäre nur leer. Der Reader lässt Fragment-`href`s zu, externe nicht.

## 4. Strapi: `room`

Ein Collection-Type **ohne** Draft & Publish — Räume sind technische Referenzdaten.

**Katalogverwaltet** (gehört `packages/campus-map`, wird vom Sync überschrieben):
`roomKey` · `editorLabel` · `roomNumber` · `buildingKey` · `buildingNameDe/En` · `floorKey` ·
`floorLevel` · `floorNameDe/En` · `roomType` · `mapVersion` · `sortOrder` · `catalogActive`

**Redaktionell** (gehört der Redaktion, wird vom Sync **nie** angefasst):
`displayNameDe/En` · `descriptionDe/En` · `isVisible` · Relationen zu `contact-person` und
`contact-area`

### 4.1 Serverseitiger Feldschutz

Die technischen Felder im Admin-Panel nur optisch zu sperren wäre wirkungslos — die Content-API und
der Document-Service bleiben erreichbar. Der Schutz hängt deshalb in der
**Document-Service-Middleware** (`src/catalog/room-guard.ts`) und greift auf **jedem** normalen
Bearbeitungsweg:

- `create` und `delete` auf `api::room.room` werden abgelehnt.
- Bei `update` werden katalogverwaltete Felder aus der Nutzlast **entfernt**, nicht abgelehnt: Das
  Admin-Panel sendet beim Speichern das ganze Dokument mit, ein Ablehnen würde jede legitime
  redaktionelle Änderung scheitern lassen. Entfernte Feldnamen werden geloggt — **nie** deren Werte.

Der Sync erhält seinen Schreibweg über eine `AsyncLocalStorage`-Scope
(`src/catalog/catalog-scope.ts`). Das ist bewusst **kein** globaler Schalter: Ein Modul-Flag würde
für den ganzen Prozess gelten und jede gleichzeitige Anfrage mit erfassen. Die Scope umfasst
ausschließlich den Aufrufbaum des Syncs und verschwindet automatisch, wenn er zurückkehrt.

### 4.2 Kontaktrelationen

`contact-person` und `contact-area` erhalten je eine `rooms`-Relation (`manyToMany`, nicht
lokalisiert — ein Raum ist dieselbe physische Sache in beiden Sprachen). **Null Räume sind ein
normaler, vollständig unterstützter Zustand**; bestehende Kontakte ohne Raum bleiben unverändert
gültig, und der freie Adresstext der Kontaktbereiche bleibt bestehen.

## 5. Raumsync

```bash
pnpm --filter @campus/cms rooms:sync -- --dry-run   # zeigt den Plan, schreibt nichts
pnpm --filter @campus/cms rooms:sync                # führt ihn aus
```

Ein **ausdrücklich manuelles** Wartungskommando. Es hängt **nicht** im Strapi-Bootstrap und läuft
**nie** aus CI — ein Live-CMS zu verändern bleibt eine bewusste Handlung.

Ablauf:

1. Katalog laden und validieren. **Ungültig ⇒ Abbruch, bevor Strapi überhaupt startet.**
2. Bestehende Räume lesen (nur katalogverwaltete Felder; Relationen werden bewusst **nicht**
   populiert, damit der Planer redaktionelle Daten gar nicht erst sieht).
3. Plan berechnen und ausgeben.
4. Bei `--dry-run` endet es hier.

| Fall                                 | Verhalten                                  |
| ------------------------------------ | ------------------------------------------ |
| Neuer `roomKey`                      | anlegen                                    |
| Bekannter `roomKey`, Felder geändert | nur katalogverwaltete Felder aktualisieren |
| Bekannter `roomKey`, unverändert     | nichts tun                                 |
| Im Katalog verschwunden              | `catalogActive=false` — **nie löschen**    |
| Wieder aufgetaucht                   | `catalogActive=true`                       |
| Zweiter Lauf                         | keine Schreibvorgänge (idempotent)         |

Die Diff-Planung (`src/catalog/room-sync-plan.ts`) ist frei von Strapi und daher **ohne Datenbank**
testbar — genau dort liegen die Garantien „redaktionelle Felder werden nie überschrieben“,
„Dry-Run schreibt nichts“ und „zweimal laufen ändert nichts“.

Logs enthalten Schlüssel und Zähler, **nie** Tokens, Datenbank-URLs oder vollständige Datensätze.

## 6. Campus API

- `GET /v1/rooms` — der vollständige öffentliche Raumkatalog. Klein und komplett, damit die App
  lokal sucht und offline weiterarbeitet; **keine** serverseitige Volltextsuche. Optionale,
  validierte Filter: `buildingKey`, `floorKey`.
- `GET /v1/rooms/:roomKey` — ein Raum; unbekannt ⇒ `404 ROOM_NOT_FOUND`.

Ausgeliefert werden **nur** Räume mit `catalogActive=true` **und** `isVisible=true`. Dieselbe
Sichtbarkeitsregel gilt auch für Räume, die über eine Kontaktrelation erreicht werden.

Das DTO trägt `roomKey`, `roomNumber`, `buildingKey`, lokalisierten `buildingName`, `floorKey`,
`floorLevel`, lokalisierten `floorName`, `roomType`, optional `displayName` und `description`,
`mapVersion` und `sortOrder`. **Keine** Strapi-Interna, **keine** Strapi-ID.

Die `room`-Collection ist **nicht** lokalisiert, sondern trägt explizite `…De`/`…En`-Paare. Der
Locale-Vertrag ist deshalb eine Feldauswahl statt eines Dokument-Overlays — mit demselben Ergebnis:
Deutsch ist kanonisch, fehlt eine englische Fassung, wird die deutsche geliefert und
`translationFallback` gesetzt.

Kontakt-DTOs tragen zusätzlich kompakte `RoomReference`-Werte (Schlüssel, Nummer, lokalisierte
Gebäude- und Etagennamen, optionaler Anzeigename) — genug für eine verständliche Zeile und einen
Sprung in den Lageplan, ohne Strapi-ID.

## 7. App

Der Plan ist **vollflächig**; alles andere schwebt darüber. Die Karte ist der
Inhalt, kein Vorschaubild zwischen Formularfeldern.

- **„Mehr → Lageplan"**, eigener Routenpfad. **Keine** sechste Bottom-Navigation.
- **Schwebende Suchleiste** oben mit Zurück-Pfeil; Treffer erscheinen als
  Overlay darunter. Gesucht wird über Raumnummer, **normalisierte** Raumnummer
  (`B.201` und `B201` finden denselben Raum), Anzeigenamen sowie Gebäude- und
  Etagenbezeichnung. Ranking: exakte Nummer → Nummernpräfix → Anzeigename →
  Ort, danach deterministisch nach `sortOrder` und `roomKey`.
- **Demo-Badge** dauerhaft sichtbar; ein Tippen zeigt den vollständigen
  Hinweistext im Dialog. Der Democharakter ist damit nie verborgen.
- **Untere Leiste** im Ruhezustand: Anzahl der Räume und „Alle anzeigen", das
  die vollständige Liste als ziehbares Sheet öffnet.
- **Detail-Sheet** unten, sobald ein Raum gewählt ist: Auswahl im Klartext,
  Gebäude/Etage/Raum, Raumart, optionale Beschreibung und „Gesamte Etage
  anzeigen".
- **Fokus respektiert die Overlays.** Die Karte liegt hinter Suchleiste und
  Sheet, deshalb zentriert die Auswahl auf die Mitte des _sichtbaren_
  Ausschnitts (`FloorMapView.visiblePadding`) — sonst läge der gewählte Raum
  hinter einem Panel.
- **Hervorhebung nie nur über Farbe**: kräftige Kontur **plus** Marker über dem
  Raum **plus** textliche Aussage „Ausgewählt: …" im Sheet; in der Liste
  zusätzlich ein eigenes Icon.
- **Gebäude- und Etagenauswahl** als kompakte schwebende Chips oben rechts,
  Gebäude über Etage — die weitere Wahl zuerst, die engere danach. Die
  Gebäudeauswahl erscheint, sobald es mehr als ein Gebäude gibt; die
  Etagenauswahl ist **immer** sichtbar und wird bei nur einer Ebene zu einer
  reinen Aussage ohne Menü (kein Pfeil, `readOnly`-Semantics). Beschriftungen
  kommen aus dem gebündelten Katalog (`nameDe`/`nameEn`), nicht aus einem
  `buildingKey`-Schalter im Code.
- **Konsistenz ist Aufgabe der Controller, nicht der Screens.** Ein
  Gebäudewechsel wählt die erste Etage dieses Gebäudes und löscht eine
  Raumauswahl, die nicht dorthin gehört; die Auswahl eines Raums (Suche,
  Kontakt-Deep-Link, Liste) schaltet Gebäude **und** Etage mit. Der Screen
  leitet beides zusätzlich defensiv ab, damit eine Etage eines anderen
  Gebäudes selbst dann nicht gezeichnet wird, wenn der Zustand es behauptet.
- **Ein Gebäude ohne Räume ist ein normaler Zustand** — keine Fehlermeldung,
  keine leere Raumdetailansicht. Die Suche bleibt global über alle Räume.
- Deep-Link `/more/campus-map?room=<roomKey>` aus Kontaktdetails.
- **Unbekannter `roomKey`**: Text anzeigen, Kartenaktion deaktivieren, nicht
  abstürzen.
- **`mapVersion`-Konflikt**: Der Plan wird zurückgehalten und erklärt; die Räume
  bleiben über die Liste erreichbar.
- Raumkatalog über den bestehenden `CachedEndpoint`/Hive-Cache; ein Cachefehler
  degradiert auf einen Netzabruf, gecachte Daten werden als offline
  gekennzeichnet.
- Eine leere Raumliste rendert **nichts** — ein Kontakt ohne Raum sieht aus wie
  zuvor.

Räume sind bewusst **nicht** durch Tippen auf beliebige SVG-Pfade auswählbar:
Das gebündelte Asset wird zur Laufzeit nicht analysiert, und Suche plus
Deep-Link decken den Bedarf vollständig ab.

## 8. Release-Gate: reale Gebäudepläne

Der aktuelle Plan ist erfunden und damit unbedenklich. **Bevor** ein realer Gebäudeplan aufgenommen
wird, ist organisatorisch und rechtlich zu klären:

1. **Herkunft** — wer hat den Plan erstellt, wem gehören die Rechte daran?
2. **Bearbeitungsrecht** — dürfen wir ihn digitalisieren, vereinfachen und umzeichnen?
3. **Veröffentlichungsrecht** — dürfen wir das Ergebnis in einer App verbreiten, und unter welcher
   Quellenangabe?
4. **Sicherheitsrelevanz** — Flucht- und Rettungspläne, Sicherheitsbereiche und Schließpläne werden
   **nicht** aufgenommen.
5. **Personenbezug** — Büros werden nicht ohne Zustimmung namentlich Personen zugeordnet.
6. **Pflege** — wer meldet Umbauten, und wie schnell?

Bis das geklärt ist, bleibt es beim fiktiven Demo-Gebäude. Der Democharakter ist in der App
sichtbar und in DE/EN formuliert.

## 9. Einen weiteren Raum, eine Etage oder ein Gebäude ergänzen

1. Geometrie im kanonischen SVG ergänzen (stabile `id` und `data-*`-Attribute).
2. Katalogeintrag ergänzen; bei einer neuen Etage `expectedRoomCount` mitpflegen.
3. `pnpm --filter @campus/map generate` — schlägt bei jeder Inkonsistenz fehl.
4. `pnpm --filter @campus/cms rooms:sync -- --dry-run` prüfen, dann ohne `--dry-run` ausführen.
5. Redaktionelle Felder und Kontaktzuordnungen in Strapi pflegen.

Ein neuer Raum braucht **keine** Flutter-Änderung. Ein weiteres Gebäude oder eine weitere Etage
ebenfalls nicht: Die Gebäude- und Etagenauswahl blendet sich erst ein, wenn es etwas zu wählen gibt,
ist aber weder im Datenmodell noch in der UI auf einen Eintrag verdrahtet. Ein neues Gebäude braucht
allerdings ein bewusstes `planKind` — der Validator lehnt jeden anderen Wert ab, damit die sichtbare
Aussage über die Karte nie geraten wird.

## 10. Grenzen (bewusst)

Keine Indoor-Navigation und keine Wegberechnung · keine Live-Position · keine Raumbelegung oder
Buchung · keine realen Gebäude oder Räume · kein SVG-Upload nach oder -Abruf aus Strapi · kein
direkter Strapi-Zugriff aus Flutter · kein CMS-Schreibzugang in der App · keine Analytics.
