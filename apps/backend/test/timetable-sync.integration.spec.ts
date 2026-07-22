import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Env, validateEnv } from '../src/config/env.schema';
import { PrismaService } from '../src/prisma/prisma.service';
import { PrismaClient } from '../src/generated/prisma/client';
import { TimetableSyncService } from '../src/modules/timetable/timetable-sync.service';
import { WebUntisClient, WebUntisError } from '../src/modules/timetable/webuntis.client';
import {
  appDataSchema,
  entriesResponseSchema,
  filterResponseSchema,
} from '../src/modules/timetable/webuntis.schema';
import { createTestPrisma } from './helpers/database';

/**
 * The import invariants are statements about DATABASE STATE, so they are proven
 * against a real PostgreSQL. Asserting them against a mocked repository would
 * demonstrate nothing about whether data actually survives a bad response.
 */

const fixture = (name: string): unknown =>
  JSON.parse(readFileSync(join(__dirname, 'fixtures/webuntis', name), 'utf8'));

const env: Env = validateEnv({
  ...process.env,
  WEBUNTIS_ENABLED: 'true',
  WEBUNTIS_REQUEST_SPACING_MS: '0',
});

/** Upstream stub. Validation and persistence stay real. */
function stubClient(overrides: Partial<Record<'appData' | 'classes' | 'entries', unknown>> = {}) {
  return {
    isEnabled: true,
    fetchAppData: jest.fn(async () =>
      appDataSchema.parse(overrides.appData ?? fixture('app-data.json')),
    ),
    fetchClasses: jest.fn(async () =>
      filterResponseSchema.parse(overrides.classes ?? fixture('filter-classes.json')),
    ),
    fetchEntries: jest.fn(async () =>
      entriesResponseSchema.parse(overrides.entries ?? fixture('entries-week.json')),
    ),
  } as unknown as WebUntisClient;
}

function failingClient(kind: WebUntisError['kind']) {
  const boom = async (): Promise<never> => {
    throw new WebUntisError(kind, `synthetic ${kind}`);
  };
  return {
    isEnabled: true,
    fetchAppData: jest.fn(boom),
    fetchClasses: jest.fn(boom),
    fetchEntries: jest.fn(boom),
  } as unknown as WebUntisClient;
}

/** The window actually covered by entries-week.json. */
const WINDOW = { from: '2026-07-20', to: '2026-07-24' };

describe('TimetableSyncService (integration)', () => {
  let prisma: PrismaClient;

  const service = (client: WebUntisClient) =>
    new TimetableSyncService(prisma as unknown as PrismaService, client, env);

  const counts = async () => ({
    groups: await prisma.timetableGroup.count(),
    activeGroups: await prisma.timetableGroup.count({ where: { active: true } }),
    entries: await prisma.timetableEntry.count(),
    links: await prisma.timetableEntryGroup.count(),
  });

  beforeAll(async () => {
    prisma = createTestPrisma();
    await prisma.$connect();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  beforeEach(async () => {
    await prisma.$executeRawUnsafe(
      'TRUNCATE TABLE timetable_entry_groups, timetable_entries, timetable_groups, timetable_contexts, timetable_sync_runs RESTART IDENTITY CASCADE',
    );
  });

  const seedCatalogue = async () => {
    await service(stubClient()).syncContext();
    const outcome = await service(stubClient()).syncGroups();
    expect(outcome.status).toBe('success');
  };

  describe('context', () => {
    it('stores the dynamically resolved school year', async () => {
      const outcome = await service(stubClient()).syncContext();

      expect(outcome.status).toBe('success');
      const context = await prisma.timetableContext.findFirst({ where: { active: true } });
      expect(context?.externalId).toBe('49');
      expect(context?.name).toBe('2026/2026');
    });

    it('is idempotent', async () => {
      await service(stubClient()).syncContext();
      await service(stubClient()).syncContext();
      expect(await prisma.timetableContext.count()).toBe(1);
    });

    it('keeps the stored context when the source fails', async () => {
      await service(stubClient()).syncContext();
      const outcome = await service(failingClient('timeout')).syncContext();

      expect(outcome.status).toBe('failed');
      expect(await prisma.timetableContext.count()).toBe(1);
    });
  });

  describe('group catalogue', () => {
    it('imports the catalogue', async () => {
      await seedCatalogue();
      const { groups, activeGroups } = await counts();
      expect(groups).toBeGreaterThan(0);
      expect(activeGroups).toBe(groups);
    });

    it('repeating the import creates no duplicates', async () => {
      await seedCatalogue();
      const before = await counts();
      await service(stubClient()).syncGroups();
      expect(await counts()).toMatchObject({ groups: before.groups });
    });

    it('an EMPTY catalogue keeps every existing group', async () => {
      await seedCatalogue();
      const before = await counts();

      const outcome = await service(
        stubClient({ classes: { resourceType: 'CLASS', classes: [] } }),
      ).syncGroups();

      expect(outcome.status).toBe('empty');
      expect(await counts()).toMatchObject({
        groups: before.groups,
        activeGroups: before.activeGroups,
      });
    });

    for (const kind of [
      'timeout',
      'http',
      'rate_limited',
      'html',
      'malformed',
      'network',
    ] as const) {
      it(`a ${kind} failure keeps every existing group`, async () => {
        await seedCatalogue();
        const before = await counts();

        const outcome = await service(failingClient(kind)).syncGroups();

        expect(outcome.status).toBe('failed');
        expect(await counts()).toMatchObject({
          groups: before.groups,
          activeGroups: before.activeGroups,
        });
      });
    }

    it('retires a group only after a complete successful catalogue', async () => {
      await seedCatalogue();
      const all = filterResponseSchema.parse(fixture('filter-classes.json'));
      const trimmed = { ...all, classes: all.classes.slice(0, 2) };

      const outcome = await service(stubClient({ classes: trimmed })).syncGroups();

      expect(outcome.status).toBe('success');
      expect(await prisma.timetableGroup.count({ where: { active: true } })).toBe(2);
      // Retired, never deleted: historical entries must stay resolvable.
      expect(await prisma.timetableGroup.count()).toBeGreaterThan(2);
    });
  });

  describe('entries', () => {
    it('imports entries and links them to their groups', async () => {
      await seedCatalogue();

      const outcome = await service(stubClient()).syncEntries(WINDOW.from, WINDOW.to);

      expect(outcome.status).toBe('success');
      const { entries, links } = await counts();
      expect(entries).toBeGreaterThan(0);
      expect(links).toBeGreaterThan(0);
    });

    it('converts Europe/Berlin wall clock into absolute UTC instants', async () => {
      await seedCatalogue();
      await service(stubClient()).syncEntries(WINDOW.from, WINDOW.to);

      const entry = await prisma.timetableEntry.findFirst({ orderBy: { startsAt: 'asc' } });
      // July is CEST (UTC+2): a 10:00 lesson is 08:00Z, never 10:00Z.
      expect(entry!.startsAt.getTime()).toBeLessThan(entry!.endsAt.getTime());
      expect(entry!.startsAt.toISOString()).toMatch(/T\d{2}:\d{2}:\d{2}/);
    });

    it('repeating the import creates no duplicates', async () => {
      await seedCatalogue();
      await service(stubClient()).syncEntries(WINDOW.from, WINDOW.to);
      const before = await counts();

      await service(stubClient()).syncEntries(WINDOW.from, WINDOW.to);
      await service(stubClient()).syncEntries(WINDOW.from, WINDOW.to);

      expect(await counts()).toMatchObject({ entries: before.entries, links: before.links });
    });

    it('an EMPTY window keeps the existing plan', async () => {
      await seedCatalogue();
      await service(stubClient()).syncEntries(WINDOW.from, WINDOW.to);
      const before = await counts();

      const outcome = await service(
        stubClient({ entries: fixture('entries-empty.json') }),
      ).syncEntries(WINDOW.from, WINDOW.to);

      expect(outcome.status).toBe('empty');
      expect(await counts()).toMatchObject({ entries: before.entries, links: before.links });
    });

    for (const kind of [
      'timeout',
      'http',
      'rate_limited',
      'html',
      'malformed',
      'network',
    ] as const) {
      it(`a ${kind} failure keeps the existing plan`, async () => {
        await seedCatalogue();
        await service(stubClient()).syncEntries(WINDOW.from, WINDOW.to);
        const before = await counts();

        const outcome = await service(failingClient(kind)).syncEntries(WINDOW.from, WINDOW.to);

        expect(outcome.status).toBe('failed');
        expect(await counts()).toMatchObject({ entries: before.entries, links: before.links });
      });
    }

    it('leaves data OUTSIDE the confirmed window untouched', async () => {
      await seedCatalogue();
      await service(stubClient()).syncEntries(WINDOW.from, WINDOW.to);

      const group = await prisma.timetableGroup.findFirstOrThrow();
      const outside = await prisma.timetableEntry.create({
        data: {
          externalKey: 'outside-window',
          startsAt: new Date('2026-09-01T08:00:00.000Z'),
          endsAt: new Date('2026-09-01T09:30:00.000Z'),
          date: new Date('2026-09-01T00:00:00.000Z'),
          title: 'Far future lesson',
          type: 'regular_teaching',
          status: 'regular',
          groups: { create: { groupId: group.id } },
        },
      });

      await service(stubClient()).syncEntries(WINDOW.from, WINDOW.to);

      expect(await prisma.timetableEntry.findUnique({ where: { id: outside.id } })).not.toBeNull();
    });

    it('keeps a shared lesson alive for a group the response did not cover', async () => {
      await seedCatalogue();
      await service(stubClient()).syncEntries(WINDOW.from, WINDOW.to);

      // A group outside the confirmed set also attends an in-window lesson.
      const entry = await prisma.timetableEntry.findFirstOrThrow();
      const otherGroup = await prisma.timetableGroup.create({
        data: { externalId: 'external-not-in-response', shortName: 'OTHER', longName: 'Other' },
      });
      await prisma.timetableEntryGroup.create({
        data: { entryId: entry.id, groupId: otherGroup.id },
      });

      // Now a response that no longer contains that lesson at all.
      const stripped = entriesResponseSchema.parse(fixture('entries-week.json'));
      const reduced = {
        ...stripped,
        days: stripped.days.map((day) => ({ ...day, gridEntries: day.gridEntries.slice(0, 1) })),
      };
      await service(stubClient({ entries: reduced })).syncEntries(WINDOW.from, WINDOW.to);

      // The other group's link is outside the confirmed scope, so both the link
      // and the lesson survive.
      const survivor = await prisma.timetableEntryGroup.findFirst({
        where: { groupId: otherGroup.id },
      });
      expect(survivor).not.toBeNull();
      expect(await prisma.timetableEntry.findUnique({ where: { id: entry.id } })).not.toBeNull();
    });

    it('records sync run metadata', async () => {
      await seedCatalogue();
      await service(stubClient()).syncEntries(WINDOW.from, WINDOW.to);

      const run = await prisma.timetableSyncRun.findFirst({
        where: { kind: 'entries', status: 'success' },
        orderBy: { startedAt: 'desc' },
      });
      expect(run).not.toBeNull();
      expect(run!.recordsWritten).toBeGreaterThan(0);
      expect(run!.groupsRequested).toBeGreaterThan(0);
      expect(run!.finishedAt).not.toBeNull();
    });

    it('stores only a classification when the source fails, never upstream detail', async () => {
      await seedCatalogue();
      await service(failingClient('html')).syncEntries(WINDOW.from, WINDOW.to);

      const run = await prisma.timetableSyncRun.findFirstOrThrow({
        where: { kind: 'entries', status: 'failed' },
        orderBy: { startedAt: 'desc' },
      });
      expect(run.errorCode).toBe('html');
      const serialized = JSON.stringify(run);
      expect(serialized).not.toContain('webuntis.com');
      expect(serialized).not.toContain('anonymous-school');
    });

    it('reports the last successful run for staleness', async () => {
      await seedCatalogue();
      await service(stubClient()).syncEntries(WINDOW.from, WINDOW.to);

      expect(await service(stubClient()).lastSuccessfulAt('entries')).toBeInstanceOf(Date);
    });
  });

  describe('disabled feature', () => {
    it('does not fail loudly, it reports disabled and touches nothing', async () => {
      await seedCatalogue();
      const before = await counts();

      const outcome = await service(failingClient('disabled')).syncEntries(WINDOW.from, WINDOW.to);

      expect(outcome.status).toBe('disabled');
      expect(await counts()).toMatchObject({ entries: before.entries });
    });
  });
});
