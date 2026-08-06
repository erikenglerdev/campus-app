import { Env } from '../../config/env.schema';
import { PrismaService } from '../../prisma/prisma.service';
import { CanteenSyncService } from '../canteen/canteen-sync.service';
import { UserTestDataSeedService } from './user-test-data.seed.service';

describe('UserTestDataSeedService safety boundary', () => {
  it('refuses to write unless the deployment explicitly opts in', async () => {
    const service = new UserTestDataSeedService(
      {} as PrismaService,
      {} as CanteenSyncService,
      { USER_TEST_DATA_ENABLED: false } as Env,
    );

    await expect(service.seed()).rejects.toThrow(/USER_TEST_DATA_ENABLED/);
  });

  it('removes only rows owned by the user-test source', async () => {
    const deleted: Array<{ model: string; where: unknown }> = [];
    const model = (name: string) => ({
      deleteMany: jest.fn(async ({ where }: { where: unknown }) => {
        deleted.push({ model: name, where });
        return { count: 1 };
      }),
    });
    const transaction = {
      syncRun: model('syncRun'),
      meal: model('meal'),
      timetableSyncRun: model('timetableSyncRun'),
      timetableEntry: model('timetableEntry'),
      timetableGroup: model('timetableGroup'),
      timetableContext: model('timetableContext'),
    };
    const prisma = {
      $transaction: jest.fn(async (operation: (tx: typeof transaction) => Promise<unknown>) =>
        operation(transaction),
      ),
    } as unknown as PrismaService;
    const service = new UserTestDataSeedService(
      prisma,
      {} as CanteenSyncService,
      { USER_TEST_DATA_ENABLED: false } as Env,
    );

    await service.remove();

    expect(deleted).toHaveLength(6);
    expect(deleted.every((operation) => operation.where)).toBe(true);
    expect(deleted).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ model: 'meal', where: { source: 'user-test' } }),
        expect.objectContaining({ model: 'timetableEntry', where: { source: 'user-test' } }),
      ]),
    );
  });
});
