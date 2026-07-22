import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { CanteenSyncService } from '../src/modules/canteen/canteen-sync.service';
import { CANTEENS } from '../src/modules/canteen/canteens.config';
import { CanteenSourceError, MeineMensaClient } from '../src/modules/canteen/meine-mensa.client';
import { foodPlanResponseSchema } from '../src/modules/canteen/meine-mensa.schema';
import { Env, validateEnv } from '../src/config/env.schema';
import { PrismaService } from '../src/prisma/prisma.service';
import { PrismaClient } from '../src/generated/prisma/client';
import { createTestPrisma, resetDatabase } from './helpers/database';

/**
 * Integration tests for the synchronisation guarantees, run against a REAL
 * database. These assertions are about persisted state, so a mocked repository
 * would not actually demonstrate anything.
 */

const FASANERIEALLEE = CANTEENS[0]!;
const LOHMANNSTRASSE = CANTEENS[1]!;

function fixture(name: string) {
  const raw = JSON.parse(
    readFileSync(join(__dirname, 'fixtures/meine-mensa', name), 'utf8'),
  ) as unknown;
  return foodPlanResponseSchema.parse(raw);
}

/** Stub source whose behaviour each test controls. */
function stubClient(
  respond: () => ReturnType<typeof fixture> | Promise<ReturnType<typeof fixture>>,
): MeineMensaClient {
  return { fetchFoodPlans: jest.fn(async () => respond()) } as unknown as MeineMensaClient;
}

describe('CanteenSyncService (integration)', () => {
  let prisma: PrismaClient;
  let env: Env;

  const makeService = (client: MeineMensaClient) =>
    new CanteenSyncService(prisma as unknown as PrismaService, client, env);

  const mealCount = () => prisma.meal.count();
  const mealNames = async () =>
    (await prisma.meal.findMany({ orderBy: { sourcePlanId: 'asc' } })).map((m) => m.name);

  beforeAll(async () => {
    env = validateEnv(process.env);
    prisma = createTestPrisma();
    await prisma.$connect();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  beforeEach(async () => {
    await resetDatabase(prisma);
  });

  describe('seeding', () => {
    it('is idempotent: running it twice creates no duplicates', async () => {
      const service = makeService(stubClient(() => fixture('success.json')));

      await service.seedCanteens();
      await service.seedCanteens();

      expect(await prisma.canteen.count()).toBe(CANTEENS.length);
    });
  });

  describe('successful synchronisation', () => {
    it('imports meals with all provided price groups and no image field', async () => {
      const service = makeService(stubClient(() => fixture('success.json')));
      await service.seedCanteens();

      const outcome = await service.syncCanteen(FASANERIEALLEE);

      expect(outcome.status).toBe('success');
      expect(outcome.recordsUpserted).toBe(3);
      expect(await mealCount()).toBe(3);

      const meal = await prisma.meal.findUnique({
        where: { sourcePlanId: 900001 },
        include: { prices: { orderBy: { group: 'asc' } } },
      });
      expect(meal!.name).toBe('Gemüsepfanne');
      expect(meal!.isSprint).toBe(true);
      expect(meal!.prices.map((p) => [p.group, p.amount.toString()])).toEqual([
        ['employee', '4.95'],
        ['guest', '7'],
        ['student', '1.95'],
      ]);
      // The schema has no image column at all.
      expect(Object.keys(meal!)).not.toContain('imageUrl');
      expect(JSON.stringify(meal)).not.toContain('mediathek');
    });

    it('stores ingredient and marker definitions with their namespace', async () => {
      const service = makeService(stubClient(() => fixture('success.json')));
      await service.seedCanteens();
      await service.syncCanteen(FASANERIEALLEE);

      const vegan = await prisma.ingredientDefinition.findUnique({ where: { code: '52' } });
      const sprint = await prisma.ingredientDefinition.findUnique({ where: { code: '53' } });

      expect(vegan).toMatchObject({ labelDe: 'vegan', kind: 'ingredient', labelEn: null });
      expect(sprint).toMatchObject({ labelDe: 'Sprint-Menü', kind: 'marker', labelEn: null });
    });

    it('records lastSuccessfulSyncAt', async () => {
      const service = makeService(stubClient(() => fixture('success.json')));
      await service.seedCanteens();
      await service.syncCanteen(FASANERIEALLEE);

      const canteen = await prisma.canteen.findUnique({ where: { slug: FASANERIEALLEE.slug } });
      expect(await service.lastSuccessfulSyncAt(canteen!.id)).toBeInstanceOf(Date);
    });

    it('omits a price group the source did not provide, rather than defaulting it', async () => {
      const service = makeService(stubClient(() => fixture('partial-prices.json')));
      await service.seedCanteens();
      await service.syncCanteen(FASANERIEALLEE);

      const meal = await prisma.meal.findUnique({
        where: { sourcePlanId: 900010 },
        include: { prices: true },
      });
      expect(meal!.prices.map((p) => p.group).sort()).toEqual(['guest', 'student']);
    });
  });

  describe('idempotency and change handling', () => {
    it('repeating the same import creates no duplicates', async () => {
      const service = makeService(stubClient(() => fixture('success.json')));
      await service.seedCanteens();

      await service.syncCanteen(FASANERIEALLEE);
      await service.syncCanteen(FASANERIEALLEE);
      await service.syncCanteen(FASANERIEALLEE);

      expect(await mealCount()).toBe(3);
      expect(await prisma.mealPrice.count()).toBe(9);
    });

    it('updates a changed dish in place and withdraws one removed upstream', async () => {
      await makeService(stubClient(() => fixture('success.json'))).seedCanteens();
      await makeService(stubClient(() => fixture('success.json'))).syncCanteen(FASANERIEALLEE);
      expect(await mealCount()).toBe(3);

      await makeService(stubClient(() => fixture('changed.json'))).syncCanteen(FASANERIEALLEE);

      const changed = await prisma.meal.findUnique({
        where: { sourcePlanId: 900001 },
        include: { prices: true },
      });
      expect(changed!.name).toBe('Gemüsepfanne (neu)');
      expect(changed!.isSprint).toBe(false);
      expect(changed!.prices.find((p) => p.group === 'student')!.amount.toString()).toBe('2.15');

      // 900003 was on a date outside the confirmed window and must survive;
      // the withdrawn dish inside the window must be gone.
      expect(await prisma.meal.findUnique({ where: { sourcePlanId: 900002 } })).not.toBeNull();
      expect(await mealNames()).toContain('Linseneintopf');
    });
  });

  describe('resilience — stored data must survive a bad response', () => {
    const seedGoodData = async () => {
      const service = makeService(stubClient(() => fixture('success.json')));
      await service.seedCanteens();
      await service.syncCanteen(FASANERIEALLEE);
      expect(await mealCount()).toBe(3);
    };

    it('keeps existing data when the source returns an EMPTY list', async () => {
      await seedGoodData();

      const outcome = await makeService(stubClient(() => fixture('empty.json'))).syncCanteen(
        FASANERIEALLEE,
      );

      expect(outcome.status).toBe('empty');
      expect(outcome.recordsRemoved).toBe(0);
      expect(await mealCount()).toBe(3);
    });

    it('keeps existing data when the request TIMES OUT', async () => {
      await seedGoodData();

      const failing = {
        fetchFoodPlans: jest.fn(async () => {
          throw new CanteenSourceError('timeout', 'source request timed out');
        }),
      } as unknown as MeineMensaClient;

      const outcome = await makeService(failing).syncCanteen(FASANERIEALLEE);

      expect(outcome.status).toBe('failed');
      expect(outcome.errorMessage).toContain('timeout');
      expect(await mealCount()).toBe(3);
    });

    it('keeps existing data when the response is MALFORMED', async () => {
      await seedGoodData();

      const failing = {
        fetchFoodPlans: jest.fn(async () => {
          throw new CanteenSourceError('malformed', 'response failed validation');
        }),
      } as unknown as MeineMensaClient;

      const outcome = await makeService(failing).syncCanteen(FASANERIEALLEE);

      expect(outcome.status).toBe('failed');
      expect(await mealCount()).toBe(3);
    });

    it('keeps existing data when the source returns an HTTP error', async () => {
      await seedGoodData();

      const failing = {
        fetchFoodPlans: jest.fn(async () => {
          throw new CanteenSourceError('http', 'source responded with status 503', 503);
        }),
      } as unknown as MeineMensaClient;

      expect((await makeService(failing).syncCanteen(FASANERIEALLEE)).status).toBe('failed');
      expect(await mealCount()).toBe(3);
    });

    it('records the failure in sync_runs without touching lastSuccessfulSyncAt', async () => {
      await seedGoodData();
      const canteen = await prisma.canteen.findUnique({ where: { slug: FASANERIEALLEE.slug } });
      const before = await makeService(
        stubClient(() => fixture('success.json')),
      ).lastSuccessfulSyncAt(canteen!.id);

      const failing = {
        fetchFoodPlans: jest.fn(async () => {
          throw new CanteenSourceError('network', 'unreachable');
        }),
      } as unknown as MeineMensaClient;
      const service = makeService(failing);
      await service.syncCanteen(FASANERIEALLEE);

      expect(await service.lastSuccessfulSyncAt(canteen!.id)).toEqual(before);
      expect(await prisma.syncRun.count({ where: { status: 'failed' } })).toBe(1);
    });
  });

  describe('location_id mismatch', () => {
    it('rejects entries belonging to another canteen and imports only the matching ones', async () => {
      const service = makeService(stubClient(() => fixture('location-mismatch.json')));
      await service.seedCanteens();

      const outcome = await service.syncCanteen(FASANERIEALLEE);

      expect(outcome.recordsReceived).toBe(2);
      expect(outcome.recordsUpserted).toBe(1);
      expect(outcome.recordsRejected).toBe(1);

      expect(await mealNames()).toEqual(['Richtiges Gericht']);
      expect(await prisma.meal.findUnique({ where: { sourcePlanId: 900020 } })).toBeNull();
    });

    it('treats a response with ONLY foreign entries as empty and keeps stored data', async () => {
      const service = makeService(stubClient(() => fixture('success.json')));
      await service.seedCanteens();
      await service.syncCanteen(FASANERIEALLEE);

      // Fasanerieallee asking, but every entry belongs to Lohmannstraße.
      const outcome = await makeService(
        stubClient(() => fixture('lohmannstrasse.json')),
      ).syncCanteen(FASANERIEALLEE);

      expect(outcome.status).toBe('empty');
      expect(outcome.recordsRejected).toBe(1);
      expect(await mealCount()).toBe(3);
    });
  });

  describe('canteen isolation', () => {
    it("keeps each canteen's meals separate", async () => {
      const service = makeService(stubClient(() => fixture('success.json')));
      await service.seedCanteens();
      await service.syncCanteen(FASANERIEALLEE);

      await makeService(stubClient(() => fixture('lohmannstrasse.json'))).syncCanteen(
        LOHMANNSTRASSE,
      );

      const fasanerieallee = await prisma.canteen.findUnique({
        where: { slug: FASANERIEALLEE.slug },
      });
      const lohmannstrasse = await prisma.canteen.findUnique({
        where: { slug: LOHMANNSTRASSE.slug },
      });

      expect(await prisma.meal.count({ where: { canteenId: fasanerieallee!.id } })).toBe(3);
      expect(await prisma.meal.count({ where: { canteenId: lohmannstrasse!.id } })).toBe(1);
    });
  });
});
