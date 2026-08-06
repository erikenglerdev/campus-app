<!-- Campus Köthen App · AGPL-3.0-only · Copyright © 2026 Erik Engler and Jona Loreen Sommer -->

# Lageplan, Raumkatalog und CMS-Raumsync

Lageplan mit Gebäude- und Etagenauswahl sowie Raumsuche unter „Mehr → Lageplan“. Die Geometrie
ist ein selbst erstelltes, versioniertes Asset im Repository; Raumbezeichnungen und redaktionelle
Texte kommen über die Campus API und werden offline gecacht.

Zwei Kartengebäude, bewusst unterschiedlicher Natur:

| Gebäude                   | `buildingKey`             | Ebene                           | Räume |
| ------------------------- | ------------------------- | ------------------------------- | ----- |
| Demogebäude Nord (fiktiv) | `demo-north`              | `demo-north-level1`             | 30    |
| Demogebäude Nord (fiktiv) | `demo-north`              | `demo-north-level2`             | 30    |
| Campus Köthen – Übersicht | `koethen-campus-overview` | `koethen-campus-overview-level` | 0     |

> ⚠️ **Das Demogebäude ist vollständig erfunden.** Beide Etagen und alle 60 Räume
> (B.101–B.130, B.201–B.230) sind Demonstrationsdaten; es wird kein realer Grundriss und kein
> realer Raum dargestellt.

Die beiden Etagen tragen bewusst **dieselbe Geometrie**: Das ist ein Demo-Asset, und zwei
Stockwerke sind da, um die Etagenauswahl, den Etagenwechsel und die Raumauflösung über mehrere
Ebenen real durchzuspielen — nicht, um zwei unterschiedliche Grundrisse zu zeigen. Schlüssel und
Raumnummern sind dagegen **strikt getrennt** (`demo-north-level1-b101` gegen
`demo-north-level2-b201`); genau daran hängt, dass ein Tap nicht im Raum eine Etage höher landet.
Die Karte öffnet die **unterste** Etage, so wie ein Haus von unten gelesen wird.

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
  Overlay darunter. Siehe §7c.
- **Demo-Badge** dauerhaft sichtbar; ein Tippen zeigt den vollständigen
  Hinweistext im Dialog. Der Democharakter ist damit nie verborgen.
- **Antippbare Räume**: siehe §7b.
- **Detail-Sheet** unten, sobald ein Raum gewählt ist: Auswahl im Klartext,
  Gebäude/Etage/Raum, Raumart, optionale Beschreibung und „Gesamte Etage
  anzeigen".
- **Fokus respektiert die Overlays.** Die Karte liegt hinter Suchleiste und
  Sheet, deshalb zentriert die Auswahl auf die Mitte des _sichtbaren_
  Ausschnitts (`FloorMapView.visiblePadding`) — sonst läge der gewählte Raum
  hinter einem Panel.
- **Der automatische Zoom bleibt schwach.** Die Auswahl vergrößert höchstens auf
  `kMaxFocusScale` (3,0), obwohl von Hand bis `maxScale` (8) gezoomt werden
  kann. Ein automatischer Sprung auf die Maximalvergrößerung beantwortet „wo ist
  dieser Raum" mit einer Nahaufnahme des Raums allein — ohne Flur, Nachbarnummern
  und Treppenhaus, also ohne alles, woran man sich orientiert. Die Konstante steht
  in `floor_map_view.dart` und ist getestet; Pinch-Zoom ist davon unberührt.
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

Das gebündelte SVG wird zur Laufzeit **nicht** analysiert. Ein Tap trifft die
**Geometrie aus `map_catalog.json`**, nicht einen SVG-Pfad — siehe §7b.

## 7a. Bedienung der Kartenansicht

Die Steuerung für **Gebäude** und **Etage** steht **links** über dem Plan, Gebäude über
Etage. Sie beschreibt, was darunter gezeichnet wird, und ein von links nach rechts lesender
Blick sucht sie dort. Die Beschriftungen sind breiter als früher, weil Gebäudenamen selten
kurz sind; die Höchstbreite ist aber an die tatsächlich verfügbare Bildschirmbreite gebunden
und nie größer. Lange Namen werden weiterhin mit Auslassungszeichen gekürzt, statt das
Bedienelement über die Karte zu schieben.

Die frühere untere Leiste mit der **Raumanzahl** und **„Alle anzeigen"** samt vollständiger
Raumliste ist entfallen. Sie belegte einen Streifen der Karte, um zu sagen, was die Karte
ohnehin zeigt. Räume werden über die **Raumsuche** gefunden — die weiterhin die
barrierefreie Bedienung ist. Ohne ausgewählten Raum wird unten kein Platz mehr für eine
Leiste reserviert, die es nicht mehr gibt; der Zurücksetzen-Knopf rückt entsprechend nach.

Enthält der Katalog **gar keine Räume**, sagt ein kurzer Hinweis unter dem Plan-Abzeichen
genau das. Ohne ihn wäre ein durchsuchbarer Plan ohne Suchtreffer stumm darüber, warum.

## 7b. Antippbare Räume

Ein Tap auf einen Raum wählt ihn aus — über **denselben** Weg wie ein Suchtreffer und mit
derselben Detailanzeige. Getroffen wird die **Geometrie aus `map_catalog.json`**, nicht ein
SVG-Pfad: Das Asset ist ein Bild, und es zur Laufzeit wie ein Dokument abzufragen würde die
App daran binden, wie der Generator es gerade ausgibt.

Die Regeln stehen als reine Funktion in `map_hit_test.dart` und sind dort einzeln getestet:

| Fall                                 | Ergebnis                                                          |
| ------------------------------------ | ----------------------------------------------------------------- |
| Tap **in** einem Raum                | dieser Raum — Enthaltensein schlägt jede Nähe                     |
| Tap in mehreren (Raum im Raum)       | der **kleinere**, sonst wäre eine Kammer in einer Halle unwählbar |
| Tap knapp daneben                    | der **nächste** Raum innerhalb der Toleranz                       |
| Tap auf freier Fläche                | **nichts** — leerer Boden ist eine echte Antwort, kein Ratefall   |
| Raum ohne passenden `/v1/rooms`-Satz | **nicht** auswählbar; es gäbe weder Namen noch Details zu zeigen  |

Zwei Punkte, die leicht falsch werden:

- **Koordinaten.** Der `GestureDetector` sitzt **innerhalb** des Kindes des
  `InteractiveViewer`. Flutter bildet den Zeiger damit selbst durch Pan und Zoom ab; es gibt
  keine eigene Umkehrrechnung, die bei Skalierung 1 stimmt und sonst nicht.
- **Toleranz.** Eine Fingerkuppe ist rund 24 logische Pixel breit. Hineingezoomt decken diese
  Pixel weniger Plan-Einheiten ab, also schrumpft die Toleranz mit dem Zoom — sonst würde ein
  vergrößerter Plan ungenauer, je näher man hinsieht.

Die **Raumsuche** bleibt die barrierefreie Bedienung: Der Plan selbst ist für Screenreader
weiterhin dekorativ (`excludeFromSemantics`), die Auswahl wird im Detail-Sheet im Klartext
genannt.

## 7c. Raumsuche

Gesucht wird lokal über den gecachten Raumkatalog — kein Netzaufruf pro Tastendruck, und
offline funktioniert es unverändert. Raumnummern werden **normalisiert** verglichen: alle
Trennzeichen fallen weg, Groß-/Kleinschreibung ist egal. `B.202`, `B202`, `b 202` und `202`
finden damit denselben Raum.

Die Rangfolge ist die Aufzählung in `RoomMatchReason` — beste Erklärung zuerst:

1. **exakte Nummer** — die Eingabe ist die Raumnummer, mit oder ohne Gebäudebuchstaben.
   `202` zählt als exakt, weil ein Stundenplan „202" schreibt und an der Tür „B.202" steht;
   sonst stünde `B.210` vor `B.21`.
2. **Nummernpräfix** — `b2` findet `B.201`, `B.202`, …
3. **Nummer enthält** die Eingabe.
4. **Anzeigename** (redaktionell, aus `/v1/rooms`).
5. **Gebäude- oder Etagenbezeichnung.**
6. **Personen und Anlaufstellen** — siehe unten.

Innerhalb einer Stufe wird deterministisch nach `sortOrder` und `roomKey` sortiert.

**Suche über Personen und Anlaufstellen.** Wer den Namen einer Person kennt, aber nicht deren
Raumnummer, findet den Raum trotzdem. Grundlage ist der **vorhandene** Kontakt-Suchindex
(`GET /v1/contact-areas/search-index`), aus dem einmalig ein `ContactRoomIndex` gefaltet wird;
gesucht wird darin mit **denselben** Umlautregeln wie in der Kontaktsuche (`ContactTerm`), damit
„Björn", „Bjoern" und „bjorn" dasselbe treffen. Solche Treffer stehen immer **hinter** allen
direkten und tragen eine Zusatzzeile „Gefunden über …" sowie ein eigenes Icon — ein Raum, in
dem der eingetippte Text nirgends vorkommt, wäre sonst unerklärlich. Ein Raum erscheint auch
dann nur **einmal**, wenn mehrere passende Personen darin sitzen.

Der Index ist rein **additiv**: Solange er lädt oder wenn er fehlschlägt, verhält sich die
Raumsuche exakt wie ohne ihn. Er ist nur enger, nie kaputt.

## 7d. Zentrale Raumauflösung und Raum-Links

`RoomResolver` (`campusmap/domain/room_mention.dart`) ist die **einzige** Stelle, die
entscheidet, ob eine geschriebene Zeichenkette einen bestimmten Raum meint. Ein Raum-Link ist
eine Anweisung — „tippe hier und du stehst vor der richtigen Tür" — und ein falscher schickt
jemanden in das falsche Gebäude. Alles, was nicht sicher ist, löst deshalb zu **nichts** auf
und bleibt einfacher Text.

Zwei Strengegrade, vom Aufrufer je Feld angegeben:

| `RoomMentionSource` | Wofür                                                                 | Regel                                                                                                                                                                |
| ------------------- | --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `designation`       | Felder, die einen Raum enthalten: Stundenplan-Raumliste, Kontakt-Raum | Der ganze Wert ist eine Raumbezeichnung. Die Kurzform (`202`) gilt — **außer** sie ist mehrdeutig (zwei Gebäude mit einer 202 ⇒ keine Auflösung).                    |
| `freeText`          | Prosa aus öffentlichen Kalendern: `LOCATION`, `DESCRIPTION`, Titel    | Nur **vollständig qualifizierte** Nennungen (`B.202`). Eine nackte Zahl bleibt eine Zahl — sie kann ein Jahr, ein Preis, eine Hausnummer oder eine Modulnummer sein. |

In beiden Fällen wird nur **exakt** aufgelöst: `B.2` wird nie zu `B.202`, und `INF202` ist kein
Raum. Räume, die der Katalog nicht kennt, ergeben keinen Link.

Die Oberfläche dazu steht einmal in `campusmap/presentation/room_link.dart`:
`RoomLinkTarget` (aus `Room` **oder** `RoomReference`), `RoomLinkTile` für Listenzeilen,
`RoomLinkButton` für Detailansichten und `RoomLinkSection` für Kontakte. Kennt der gebündelte
Plan den `roomKey` nicht — eine ältere App mit einem neueren Katalog —, bleibt die Zeile
lesbarer Text statt eines Links ins Leere. Aus einem Sheet heraus wird das Sheet **vor** der
Navigation geschlossen, sonst verdeckte es genau den Raum, den es zeigen sollte.

## 7e. Detailansichten von Terminen

Stundenplan-Karten und Kalendereinträge öffnen **dieselbe** Detailansicht
(`calendar/presentation/calendar_entry_sheet.dart`) — ein Termin hat eine Detailansicht,
gleich von welchem Bildschirm aus er angetippt wurde. Erreichbar ist sie aus der Tagesagenda,
der Liste, der Wochenansicht **und** aus dem Ganztagesband, in dem jeder Eintrag ein eigener
Chip mit vollem Tap-Ziel ist statt einer zusammengefügten Zeile.

Damit das geht, trägt `CalendarEntry` neben den flachgeklopften Anzeigefeldern ein typisiertes,
quellenspezifisches `CalendarEntryDetails`: `TimetableCalendarDetails` (Art, Status,
Lehrpersonen, Räume, Gruppen, Notiz), `MoodleCalendarDetails` (Kurs, Aktivität) und
`PublicCalendarDetails` (Kalendername, Ort, Beschreibung). Jede Variante sagt selbst, welche
ihrer Texte als **Raumbezeichnung** und welche als **Prosa** gelesen werden dürfen
(`roomDesignations` / `roomProse`); die Detailansicht wendet nur an, was dort steht. Damit ist
„niemals zum falschen Raum" eine Entscheidung im Modell statt einer pro Bildschirm.

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

Ebenso bewusst: **keine heuristische Raumverlinkung.** Kein Raten aus Teilnummern, keine
Auswahl „des wahrscheinlichsten" Raums bei Mehrdeutigkeit, keine nackten Zahlen aus Freitext.
Lieber kein Link als einer zur falschen Tür — siehe §7d.
