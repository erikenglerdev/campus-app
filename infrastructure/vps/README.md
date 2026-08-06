# Portable VPS deployment

This directory is the source-checkout-free deployment contract for Campus
Koethen. The target server pulls immutable CMS and backend images from GHCR; it
does not build images and does not need a clone of this repository.

## Files needed on the VPS

Only two files are required at runtime:

```text
compose.yaml
.env
```

The database bootstrap is embedded in `compose.yaml`. PostgreSQL data and
Strapi uploads live in named Docker volumes. Nginx and TLS termination remain
outside Docker and forward to the loopback ports configured in `.env`.

Use `.env.example` for a new installation. For the existing eriklabs.eu DEV
layout, copy `.env.eriklabs-dev.example` to `.env` and fill the empty secrets
only on the VPS.

## Download without cloning the repository

Create an empty deployment directory on the VPS and download the two public,
non-secret deployment files:

```bash
mkdir -p /root/dev/docker/campus
cd /root/dev/docker/campus
curl -fsSLO https://raw.githubusercontent.com/erikenglerdev/campus-app/main/infrastructure/vps/compose.yaml
curl -fsSL https://raw.githubusercontent.com/erikenglerdev/campus-app/main/infrastructure/vps/.env.eriklabs-dev.example -o .env
chmod 600 .env
```

If the repository is private, copy the files over an authenticated channel
instead. Do not place a GitHub token in a URL or shell history.

Edit `.env`. Every credential is empty and has a generation or bootstrap note
immediately above it. Set `CAMPUS_IMAGE_TAG` to the immutable
`sha-<full commit SHA>` tag from a successful Images workflow. CMS and backend
must use the same tag.

Validate interpolation without printing the resolved secret-bearing config:

```bash
docker compose config --quiet
```

If the GHCR packages are private, authenticate Docker to `ghcr.io` with a token
that has `read:packages`. Public packages need no login.

## First start

Start PostgreSQL, its idempotent bootstrap, and Strapi:

```bash
docker compose pull db db-init cms
docker compose up -d db cms
docker compose ps --all
```

Create the first Strapi administrator at the configured CMS URL. Then create a
server-side read-only API token, put it into `STRAPI_API_TOKEN` in `.env`, and
leave Strapi's Public role without general content permissions.

Apply the committed application migrations and start API and worker:

```bash
docker compose pull api worker migrate
docker compose --profile migrate run --rm migrate
docker compose up -d api worker
```

The host reverse proxy should now forward the configured public CMS URL to
`CMS_BIND_ADDRESS:CMS_HOST_PORT` and the public API URL to
`API_BIND_ADDRESS:API_HOST_PORT`.

## Verify

With the eriklabs.eu defaults:

```bash
curl -i http://127.0.0.1:3020/_health
curl -i http://127.0.0.1:3021/health/live
curl -i http://127.0.0.1:3021/health/ready
curl -i https://strapi-dev.eriklabs.eu/_health
curl -i https://campus-backend-dev.eriklabs.eu/health/ready
docker compose ps --all
docker compose logs --since=10m --tail=200 cms api worker
```

Expected HTTP statuses are 204 for the CMS health endpoint and 200 for both API
health endpoints. `db-init` should be exited with status 0; it is a successful
one-off service, not a daemon.

After the campus-map image is deployed, review and apply the idempotent room
catalogue sync:

```bash
docker compose exec cms node dist/scripts/rooms-sync.js --dry-run
docker compose exec cms node dist/scripts/rooms-sync.js
```

## Normal rollout

Make a database and uploads backup first. Then change the single
`CAMPUS_IMAGE_TAG` value in `.env` and run:

```bash
docker compose config --quiet
docker compose pull cms api worker migrate
docker compose stop api worker
docker compose --profile migrate run --rm migrate
docker compose up -d cms
docker compose up -d api worker
docker compose ps --all
```

Nginx needs no deployment change because the host ports remain stable. An image
rollback uses the previous immutable tag, but it does not undo a database
migration.

## Persistence and secrets

Compose creates two named volumes under `COMPOSE_PROJECT_NAME`:

- `postgres_data` contains both isolated databases;
- `strapi_uploads` contains uploaded CMS files.

Back up both before upgrades and keep offsite backups with tested restores.
Never run `docker compose down --volumes` for an installation whose data must be
retained.

The committed `*.example` files contain no credentials. The filled `.env` is
ignored by Git and must exist only on the target server or in an appropriate
secret manager.
