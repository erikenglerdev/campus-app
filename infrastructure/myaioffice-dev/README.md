# DEV deployment contract — myaioffice.de

> **Nothing in this repository deploys anything.**
> This directory documents _how_ a deployment would be performed. Every step
> below is a deliberate, manual action by a human on the server. There is no
> SSH step in CI, no server secret in this repository and no automatic rollout.

---

## 1. What already exists on the server

|                      |                                                                         |
| -------------------- | ----------------------------------------------------------------------- |
| Host                 | `myaioffice.de`, Linux x86_64 (`linux/amd64`)                           |
| Deployment directory | `/home/nexa/docker/campus-koethen-dev`                                  |
| PostgreSQL           | 16, already running and healthy                                         |
| Databases / roles    | `campus_cms_dev` / `campus_cms`, `campus_app_dev` / `campus_app`        |
| TLS                  | `cms-dev.myaioffice.de` and `api-dev.myaioffice.de`, valid certificates |
| Proxy targets        | `cms-dev` → `127.0.0.1:3020`, `api-dev` → `127.0.0.1:3021`              |

Until the containers run, **both hosts return 502. That is the expected state**
and is exactly why `uptime.yml` stays gated behind `DEV_UPTIME_ENABLED`.

Database passwords exist only on the server. They are never read into this
repository, a commit, an issue or a CI log.

## 2. Images

| Image                                      | Contents                                                               |
| ------------------------------------------ | ---------------------------------------------------------------------- |
| `ghcr.io/erikenglerdev/campus-app-cms`     | Strapi 5 including the pre-built admin UI, `0.0.0.0:1337`, `/_health`  |
| `ghcr.io/erikenglerdev/campus-app-backend` | Campus API and worker, `0.0.0.0:3000`, `/health/live`, `/health/ready` |

Both are built for **`linux/amd64` only**, run as the unprivileged `node` user
(uid 1000) and are published by `.github/workflows/images.yml` on every push to
`main` with the tags `main`, `dev` and `sha-<full commit sha>`.

**There is no `latest` tag.** Deploy by digest or by the `sha-` tag: `main` and
`dev` move, so a rollout pinned to them cannot be reproduced or rolled back.

The worker uses the _same_ backend image with the command `node dist/worker.js`.

## 3. Deployment procedure

```bash
cd /home/nexa/docker/campus-koethen-dev

# 1. Configuration — real values live only here, on the server.
cp .env.example .env
$EDITOR .env            # set the sha- image tags and every REPLACE_ME

# 2. Fetch the pinned images.
docker compose pull

# 3. Apply database migrations as a one-off task, BEFORE starting the API.
#    `migrate deploy` only applies committed migrations and never needs a
#    shadow database, so campus_app keeps no CREATEDB privilege.
docker compose --profile migrate run --rm migrate

# 4. Start.
docker compose up -d
docker compose ps
```

### First start only

1. Open `https://cms-dev.myaioffice.de/admin` and create the **first Super-Admin
   manually**. There is no seeded account and no default password anywhere in
   this repository.
2. Create the read-only API token, copy it into `.env` as `STRAPI_API_TOKEN`,
   then `docker compose up -d api worker`.
3. Verify that the Strapi **Public Role has no permissions**. The Campus API
   authenticates with its own read-only token; nothing needs to be world
   readable in Strapi.

## 4. Verification after a rollout

```bash
curl -i https://cms-dev.myaioffice.de/_health      # expect 204
curl -i https://api-dev.myaioffice.de/health/live  # expect 200
curl -i https://api-dev.myaioffice.de/health/ready # expect 200, database + strapi ok
curl -s  https://api-dev.myaioffice.de/v1/canteens | head
```

`/health/live` checks the process only — it must never fail because a
dependency is down, or an outage would turn into a container restart loop.
`/health/ready` checks the database and Strapi with bounded timeouts.

Then enable the scheduled uptime check by setting the repository variable
`DEV_UPTIME_ENABLED` to exactly `true`.

## 5. Rollback

```bash
$EDITOR .env                    # set both *_IMAGE_TAG back to the previous sha-
docker compose pull
docker compose up -d
```

Because tags are immutable, the previous image is byte-for-byte what ran before.
**Check whether the rollback crosses a database migration** — a migration that
dropped or rewrote a column is not undone by pulling an older image and needs a
deliberate, separately tested down-path.

## 6. Backups — NOT set up

Offsite backups are an **open release gate**. Nothing in this repository
configures, schedules or verifies them, and no such claim should be made.

What needs backing up, together and consistently:

| Item                 | Why                                                 |
| -------------------- | --------------------------------------------------- |
| `campus_cms_dev`     | all editorial content                               |
| `campus_app_dev`     | imported canteen data and sync state                |
| `cms-uploads` volume | uploaded media, which is **not** in either database |

A database dump without the matching uploads restores articles whose images are
gone. Reference commands for a manual, local dump:

```bash
docker compose exec -T cms sh -c 'tar -C /opt/app/public -cf - uploads' > uploads-$(date +%F).tar
pg_dump --format=custom --dbname="$CMS_DSN" --file="campus_cms_dev-$(date +%F).dump"
pg_dump --format=custom --dbname="$APP_DSN" --file="campus_app_dev-$(date +%F).dump"
```

A backup that has never been restored is a hypothesis, not a backup. Restoring
into a scratch database must be part of accepting this gate.

## 7. Explicitly out of scope here

- automatic deployment, SSH from CI, server secrets in the repository
- changes to DNS, nginx, certbot or the server's own compose files
- publishing a PostgreSQL image (the official pinned `postgres:16-alpine` is used
  locally; the server's existing instance is used here)
- exposing PostgreSQL publicly — it stays bound to loopback
- Sentry, analytics, SMTP and production monitoring (all post-MVP)
