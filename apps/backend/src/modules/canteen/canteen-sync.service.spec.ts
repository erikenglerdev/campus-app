import { Env } from '../../config/env.schema';
import { PrismaService } from '../../prisma/prisma.service';
import { CanteenSyncService } from './canteen-sync.service';
import { MeineMensaClient } from './meine-mensa.client';
import { NormalizedMeal } from './meine-mensa.schema';

describe('CanteenSyncService persistence boundary', () => {
  it('withdraws only meals owned by the meine-mensa source', async () => {
    const deleteMany = jest.fn().mockResolvedValue({ count: 0 });
    const tx = {
      ingredientDefinition: { upsert: jest.fn() },
      meal: {
        upsert: jest.fn().mockResolvedValue({ id: 'meal-id' }),
        deleteMany,
      },
      mealPrice: {
        deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
        createMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
    };
    const prisma = {
      $transaction: jest.fn(async (operation: (transaction: typeof tx) => Promise<number>) =>
        operation(tx),
      ),
    } as unknown as PrismaService;
    const service = new CanteenSyncService(
      prisma,
      {} as MeineMensaClient,
      {} as Env,
    ) as unknown as {
      persist: (
        canteenId: string,
        meals: NormalizedMeal[],
        definitions: Array<{ code: string; labelDe: string; kind: 'ingredient' | 'marker' }>,
      ) => Promise<number>;
    };

    await service.persist(
      'canteen-id',
      [
        {
          sourcePlanId: 123,
          sourceFoodId: 456,
          date: '2026-08-06',
          counterId: 1,
          isSprint: false,
          name: 'Gericht',
          subtitle: null,
          extras: [],
          ingredientCodes: [],
          prices: [{ group: 'student', amount: '2.00' }],
        },
      ],
      [],
    );

    expect(deleteMany).toHaveBeenCalledWith({
      where: expect.objectContaining({ source: 'meine-mensa' }),
    });
  });
});
