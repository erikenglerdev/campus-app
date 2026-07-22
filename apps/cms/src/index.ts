import type { Core } from '@strapi/strapi';
import { ensureLocales } from './bootstrap/locales';
import { seedDemoContent } from './bootstrap/seed';

export default {
  /**
   * Runs before the application is initialised.
   */
  register(/* { strapi }: { strapi: Core.Strapi } */) {},

  /**
   * Runs before the application starts serving.
   *
   * Two idempotent steps:
   *  1. Ensure the `de` and `en` locales exist, with German as the default.
   *  2. Optionally seed neutral demo content, gated behind SEED_DEMO_CONTENT
   *     so a production boot never writes placeholder records.
   */
  async bootstrap({ strapi }: { strapi: Core.Strapi }) {
    await ensureLocales(strapi);

    if (process.env.SEED_DEMO_CONTENT === 'true') {
      await seedDemoContent({ strapi });
    }
  },
};
