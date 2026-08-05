import { INestApplication, VersioningType } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { PrismaClient } from '../src/generated/prisma/client';
import { createTestPrisma } from './helpers/database';

/**
 * API-level tests over real HTTP against a real database.
 *
 * The interesting part here is the semantic classification: the app filters on
 * `traits` and `allergens`, so the mapping from the source's own code namespace
 * has to arrive intact at the edge, not just in a unit test.
 */
describe('/v1/canteens (integration)', () => {
  let app: INestApplication;
  let prisma: PrismaClient;
  let canteenId: string;

  const DATE = '2026-07-20';

  beforeAll(async () => {
    prisma = createTestPrisma();
    await prisma.$connect();

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication({ logger: false });
    app.enableVersioning({ type: VersioningType.URI, prefix: 'v' });
    app.useGlobalFilters(new AllExceptionsFilter());
    await app.init();
  });

  afterAll(async () => {
    await app?.close();
    await prisma?.$disconnect();
  });

  beforeEach(async () => {
    await prisma.$executeRawUnsafe(
      'TRUNCATE TABLE meal_prices, meals, ingredient_definitions, sync_runs, canteens RESTART IDENTITY CASCADE',
    );

    const canteen = await prisma.canteen.create({
      data: {
        slug: 'koethen-fasanerieallee',
        sourceLocationId: 7,
        displayNameDe: 'Mensa Köthen',
        displayNameEn: 'Köthen Canteen',
        campusLabelDe: 'Fasanerieallee',
        campusLabelEn: 'Fasanerieallee',
        sortOrder: 10,
        active: true,
      },
    });
    canteenId = canteen.id;

    // The dictionary exactly as the source publishes it.
    await prisma.ingredientDefinition.createMany({
      data: [
        { code: '52', labelDe: 'vegan', kind: 'ingredient' },
        { code: 'A1', labelDe: 'enthält Weizengluten', kind: 'ingredient' },
        { code: 'G2', labelDe: 'enthält Mandeln', kind: 'ingredient' },
        { code: '2', labelDe: 'Konservierungsstoffe', kind: 'ingredient' },
        { code: '9901', labelDe: 'Klima-Teller', kind: 'marker' },
      ],
    });
  });

  async function createMeal(
    overrides: Partial<{
      sourcePlanId: number;
      name: string;
      isSprint: boolean;
      ingredientCodes: string[];
    }> = {},
  ) {
    return prisma.meal.create({
      data: {
        canteenId,
        sourcePlanId: overrides.sourcePlanId ?? 900001,
        sourceFoodId: 1001,
        date: new Date(`${DATE}T00:00:00.000Z`),
        counterId: 44,
        isSprint: overrides.isSprint ?? false,
        name: overrides.name ?? 'Gemüsepfanne',
        subtitle: 'mit Kichererbsen',
        extras: [],
        ingredientCodes: overrides.ingredientCodes ?? ['52', 'A1', 'G2', '2', '9901'],
        prices: { create: [{ group: 'student', amount: '1.95' }] },
      },
    });
  }

  async function fetchMeals() {
    const response = await request(app.getHttpServer())
      .get(`/v1/canteens/koethen-fasanerieallee/menu?from=${DATE}&to=${DATE}`)
      .expect(200);
    const body = response.body as {
      data: { days: Array<{ date: string; meals: Array<Record<string, unknown>> }> };
    };
    return body.data.days[0]!.meals;
  }

  describe('semantic traits and allergens', () => {
    it('publishes stable keys next to the raw source markers', async () => {
      await createMeal();

      const meal = (await fetchMeals())[0]!;

      expect(meal['traits']).toEqual(['vegan']);
      // The parent facet comes with the subtype: somebody avoiding gluten must
      // not have to know that "A1" means wheat.
      expect(meal['allergens']).toEqual(['gluten', 'gluten_wheat', 'nuts', 'nuts_almond']);
      // Nothing is taken away: every source code is still there to be shown.
      expect((meal['markers'] as Array<{ code: string }>).map((m) => m.code)).toEqual([
        '52',
        'A1',
        'G2',
        '2',
        '9901',
      ]);
    });

    it('gives an unclassifiable marker no invented key', async () => {
      await createMeal({ ingredientCodes: ['2', '9901'] });

      const meal = (await fetchMeals())[0]!;

      expect(meal['traits']).toEqual([]);
      expect(meal['allergens']).toEqual([]);
      expect(meal['markers']).toHaveLength(2);
    });

    it('takes the sprint menu from the plan entry', async () => {
      await createMeal({ isSprint: true, ingredientCodes: [] });

      const meal = (await fetchMeals())[0]!;

      expect(meal['traits']).toEqual(['sprint']);
    });

    it('orders the keys by the published taxonomy, not by the source', async () => {
      // Same dish, codes listed the other way round.
      await createMeal({ ingredientCodes: ['G2', 'A1'] });

      const meal = (await fetchMeals())[0]!;

      expect(meal['allergens']).toEqual(['gluten', 'gluten_wheat', 'nuts', 'nuts_almond']);
    });
  });

  it('serves every price group the source provided', async () => {
    await createMeal();

    const meal = (await fetchMeals())[0]!;

    expect(meal['prices']).toEqual([
      { group: 'student', label: 'Studierende', amount: '1.95', currency: 'EUR' },
    ]);
  });
});
