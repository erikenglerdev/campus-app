// Prisma 7 configuration.
//
// The connection URL lives here (not in schema.prisma) and is used by the
// Prisma CLI for `migrate` and `db` commands. The runtime client uses the
// @prisma/adapter-pg driver adapter instead — see src/prisma/prisma.service.ts.
//
// DATABASE_URL is never hardcoded; it comes from the environment in every
// environment, including CI.

import 'dotenv/config';
import { defineConfig, env } from 'prisma/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  datasource: {
    url: env('DATABASE_URL'),
    // Only used by `prisma migrate dev` during LOCAL development. The
    // application role is intentionally not a superuser and cannot create
    // databases, so the shadow database is provisioned up front by
    // infrastructure/local/initdb. `prisma migrate deploy`, which is what runs
    // on the server, never uses a shadow database.
    shadowDatabaseUrl: env('SHADOW_DATABASE_URL'),
  },
});
