import { Env } from '../../config/env.schema';
import { PrismaService } from '../../prisma/prisma.service';
import { TimetableService } from './timetable.service';

describe('TimetableService feature availability', () => {
  it('serves the seeded timetable when user-test data is enabled without WebUntis', () => {
    const service = new TimetableService(
      {} as PrismaService,
      {
        WEBUNTIS_ENABLED: false,
        USER_TEST_DATA_ENABLED: true,
      } as Env,
    );

    expect(service.featureEnabled).toBe(true);
  });
});
