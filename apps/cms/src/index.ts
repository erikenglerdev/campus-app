import type { Core } from '@strapi/strapi';
import { ensureLocales } from './bootstrap/locales';
import { seedDemoContent } from './bootstrap/seed';
import { createRoomGuard } from './catalog/room-guard';

export default {
  /**
   * Runs before the application is initialised.
   *
   * Installs the room guard into the document-service middleware chain so that
   * catalogue-managed technical fields cannot be changed through any normal
   * editing path — admin panel or content API alike. Only the explicit
   * `rooms:sync` write path may touch them.
   */
  register({ strapi }: { strapi: Core.Strapi }) {
    const guard = createRoomGuard({
      warn: (message: string) => strapi.log.warn(`[rooms] ${message}`),
    });
    strapi.documents.use((context, next) => guard(context as never, next as never));
  },

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
