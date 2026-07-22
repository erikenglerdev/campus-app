/**
 * Creates (or rotates) the READ-ONLY API token the Campus API uses.
 *
 * The Campus API is the only consumer of Strapi's REST API, and it never needs
 * write access — so it gets a `read-only` token rather than full access, and
 * the Strapi Public Role stays without any permissions at all.
 *
 * Usage:
 *   pnpm --filter @campus/cms token:create-readonly [name]
 *
 * The access key is printed ONCE, to stdout, and is never stored in the
 * repository. Copy it into apps/backend/.env as STRAPI_API_TOKEN.
 */

import { createStrapi, compileStrapi } from '@strapi/strapi';

const DEFAULT_NAME = 'campus-api-read-only';

interface ApiTokenService {
  create(data: {
    name: string;
    description: string;
    type: 'read-only' | 'full-access' | 'custom';
    lifespan: number | null;
  }): Promise<{ accessKey: string; name: string }>;
  getByName(name: string): Promise<{ id: number } | null>;
  revoke(id: number): Promise<unknown>;
}

async function main(): Promise<void> {
  const name = process.argv[2] ?? DEFAULT_NAME;

  const app = await createStrapi({ appDir: process.cwd(), distDir: 'dist' }).load();
  const service = app.service('admin::api-token') as unknown as ApiTokenService;

  // Rotating means revoking the previous one, so an old key cannot linger.
  const existing = await service.getByName(name);
  if (existing) {
    await service.revoke(existing.id);
    process.stderr.write(`Revoked the previous token named "${name}".\n`);
  }

  const token = await service.create({
    name,
    description:
      'Read-only token used by the Campus API. Never grants write access; the Public Role stays without permissions.',
    type: 'read-only',
    lifespan: null,
  });

  process.stderr.write(
    `\nCreated read-only token "${token.name}".\n` +
      `Copy the value below into apps/backend/.env as STRAPI_API_TOKEN.\n` +
      `It is shown only once and must never be committed.\n\n`,
  );
  // stdout carries ONLY the key, so it can be piped safely.
  process.stdout.write(`${token.accessKey}\n`);

  await app.destroy();
  process.exit(0);
}

void main().catch((error: unknown) => {
  process.stderr.write(
    `Failed to create the token: ${error instanceof Error ? error.message : 'unknown error'}\n`,
  );
  process.exit(1);
});

// Keep the compiler aware of the unused import in some Strapi versions.
void compileStrapi;
