# Lokale Entwicklung

Campus Köthen App · `AGPL-3.0-only`

---

## 1. Werkzeuge

| Werkzeug | Erwartet | Prüfen |
| --- | --- | --- |
| Node.js | 22.x | `node --version` |
| pnpm | >= 10 | `corepack enable && pnpm --version` |
| Docker + Compose | Docker 29.x, Compose v5 | `docker compose version` |
| Flutter | stable | `flutter doctor -v` |

Node 22 ist gewählt, weil Strapi 5.50 offiziell `node >=20.0.0 <=26.x.x` unterstützt. Die Version
ist in `package.json` unter `engines` und in den Dockerfiles gepinnt.

## 2. Erststart

```bash
corepack enable
pnpm install --frozen-lockfile
```

### 2.1 Datenbanken

Der lokale Compose-Stack startet **zwei getrennte Datenbanken mit getrennten Rollen** in einer
PostgreSQL-16-Instanz — genau wie auf dem Server.

```bash
cp infrastructure/local/.env.example infrastructure/local/.env
pnpm compose:local:up
docker compose -f infrastructure/local/compose.yaml ps
```

PostgreSQL wird ausschließlich an `127.0.0.1` gebunden, nie an `0.0.0.0`.

### 2.2 Backend

```bash
cp apps/backend/.env.example apps/backend/.env
pnpm --filter @campus/backend prisma:generate
pnpm --filter @campus/backend prisma:migrate:dev
pnpm --filter @campus/backend start:dev
```

| URL | Zweck |
| --- | --- |
| <http://localhost:3000/health/live> | Prozess lebt |
| <http://localhost:3000/health/ready> | Datenbank + Strapi erreichbar |
| <http://localhost:3000/docs> | OpenAPI / Swagger UI |

### 2.3 CMS

```bash
cp apps/cms/.env.example apps/cms/.env
pnpm --filter @campus/cms develop
```

Beim ersten Start unter <http://localhost:1337/admin> einen Super-Admin anlegen. Es gibt **keinen**
vorkonfigurierten Standard-Account und kein Standard-Passwort im Repository.

Danach ein Read-only-API-Token erzeugen und in `apps/backend/.env` als `STRAPI_API_TOKEN`
eintragen. Details: [content-editor-guide.md](content-editor-guide.md).

### 2.4 Seeds

```bash
pnpm --filter @campus/cms seed          # News-Kanäle + Demo-Kontaktbereiche, de + en
pnpm --filter @campus/backend seed:canteens
```

Beide Seeds sind **idempotent** — zweimaliges Ausführen erzeugt keine Duplikate.

### 2.5 Mensadaten

```bash
# Administrativer manueller Sync gegen die echte Quelle
pnpm --filter @campus/backend sync:canteens

# Offline-Variante gegen gespeicherte Fixtures
pnpm --filter @campus/backend sync:canteens -- --fixture
```

Es gibt bewusst **keinen öffentlichen, ungeschützten Sync-Endpunkt**.

### 2.6 Flutter

```bash
cd apps/mobile
flutter pub get
flutter gen-l10n
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

Für den Android-Emulator ist `localhost` des Hosts unter `10.0.2.2` erreichbar:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

## 3. Qualitätsgates

```bash
pnpm install --frozen-lockfile
pnpm format:check
pnpm lint
pnpm typecheck
pnpm test
pnpm --filter @campus/cms build

cd apps/mobile
flutter gen-l10n
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## 4. Container lokal bauen

```bash
docker build -f apps/cms/Dockerfile -t campus-app-cms:local .
docker build -f apps/backend/Dockerfile -t campus-app-backend:local .
```

Die veröffentlichten Images sind ausschließlich `linux/amd64`. Auf Apple Silicon läuft ein
`--platform linux/amd64`-Build per Emulation und ist deutlich langsamer; der verbindliche
amd64-Nachweis entsteht in `.github/workflows/images.yml`.

## 5. Vollständiger lokaler Stack

```bash
docker compose -f infrastructure/local/compose.yaml --profile full up -d --build
docker compose -f infrastructure/local/compose.yaml ps
./scripts/smoke-test.sh
```

## 6. Bekannte Toolchain-Einschränkungen

`flutter gen-l10n`, `dart format`, `flutter analyze` und `flutter test` benötigen **keine** mobile
Plattform-Toolchain und laufen auf jedem Entwicklungsrechner.

Für einen echten Gerätestart gilt zusätzlich:

| Ziel | Bedarf |
| --- | --- |
| iOS-Simulator | vollständiges Xcode aus dem App Store, danach `sudo xcodebuild -runFirstLaunch` und `brew install cocoapods` |
| Android-Emulator | Android SDK **inklusive `cmdline-tools`** sowie `flutter doctor --android-licenses` |

Fehlt eine dieser Toolchains, bleiben Analyse und Tests trotzdem vollständig ausführbar; der
Gerätestart ist dann ein dokumentierter Blocker und wird **nicht** als erfolgreich gemeldet.
