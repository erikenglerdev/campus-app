import { Inject, Injectable } from '@nestjs/common';
import { ApiError } from '../../common/errors/api-error';
import { LocaleResolution } from '../../common/locale/locale';
import { ENV } from '../../config/app-config.module';
import { Env } from '../../config/env.schema';
import { PrismaService } from '../../prisma/prisma.service';
import { TIMETABLE_TIMEZONE } from './webuntis.schema';
import {
  TimetableDayDto,
  TimetableEntryDto,
  TimetableGroupDto,
  TimetableRoomDto,
  TimetableStatusDto,
  TimetableTeacherDto,
  TimetableWeekDto,
} from './timetable.types';

/**
 * Read model for /v1/timetable*.
 *
 * Reads only from our own database. A client request never triggers an
 * upstream call — that is the worker's job, and keeping it that way is what
 * stops the API from becoming an unthrottled proxy onto a third party.
 *
 * Nothing here is translated: subjects, rooms, teachers and group names are
 * the source's own strings.
 */

type StoredRef = { shortName?: unknown; longName?: unknown; displayName?: unknown };

@Injectable()
export class TimetableService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  get featureEnabled(): boolean {
    return this.env.WEBUNTIS_ENABLED;
  }

  private isStale(at: Date | null): boolean {
    if (!at) {
      return true;
    }
    return (Date.now() - at.getTime()) / 60_000 > this.env.WEBUNTIS_STALE_AFTER_MINUTES;
  }

  private async lastSuccessful(kind: 'groups' | 'entries'): Promise<Date | null> {
    const run = await this.prisma.timetableSyncRun.findFirst({
      where: { kind, status: 'success', finishedAt: { not: null } },
      orderBy: { finishedAt: 'desc' },
    });
    return run?.finishedAt ?? null;
  }

  private static mapGroup(group: {
    id: string;
    shortName: string;
    longName: string;
    department: string | null;
  }): TimetableGroupDto {
    // Written out field by field: spreading would eventually leak externalId.
    return {
      id: group.id,
      shortName: group.shortName,
      longName: group.longName,
      department: group.department,
    };
  }

  private static mapRefs<T>(value: unknown, map: (ref: StoredRef) => T | null): T[] {
    if (!Array.isArray(value)) {
      return [];
    }
    return value
      .map((item) => (typeof item === 'object' && item !== null ? map(item as StoredRef) : null))
      .filter((item): item is T => item !== null);
  }

  async listGroups(
    locale: LocaleResolution,
    filter: { query?: string; department?: string },
  ): Promise<{ data: TimetableGroupDto[]; lastSyncAt: Date | null; stale: boolean }> {
    const lastSyncAt = await this.lastSuccessful('groups');

    if (!this.featureEnabled) {
      return { data: [], lastSyncAt, stale: true };
    }

    const query = filter.query?.trim();
    const groups = await this.prisma.timetableGroup.findMany({
      where: {
        active: true,
        ...(filter.department ? { department: filter.department } : {}),
        ...(query
          ? {
              OR: [
                { shortName: { contains: query, mode: 'insensitive' as const } },
                { longName: { contains: query, mode: 'insensitive' as const } },
                { department: { contains: query, mode: 'insensitive' as const } },
              ],
            }
          : {}),
      },
      orderBy: [{ shortName: 'asc' }],
      // The full catalogue is ~270 rows and is delivered in one response, but
      // the cap keeps an unexpected catalogue explosion from becoming an
      // unbounded payload.
      take: 500,
    });

    void locale;
    return {
      data: groups.map((group) => TimetableService.mapGroup(group)),
      lastSyncAt,
      stale: this.isStale(lastSyncAt),
    };
  }

  async getWeek(
    locale: LocaleResolution,
    groupId: string,
    range: { from: string; to: string },
  ): Promise<{
    data: TimetableWeekDto;
    lastSyncAt: Date | null;
    stale: boolean;
    dataState: 'ready' | 'pending' | 'unavailable';
  }> {
    const group = await this.prisma.timetableGroup.findFirst({ where: { id: groupId } });
    if (!group) {
      throw new ApiError('TIMETABLE_GROUP_NOT_FOUND', locale.resolvedLocale);
    }

    const lastSyncAt = await this.lastSuccessful('entries');
    const rangeStart = new Date(`${range.from}T00:00:00.000Z`);
    const rangeEnd = new Date(`${range.to}T00:00:00.000Z`);

    // Every day of the range is present, so the client can tell a genuinely
    // free day from a loading failure — the same rule the canteen menu uses.
    const byDate = new Map<string, TimetableEntryDto[]>();
    for (let cursor = rangeStart.getTime(); cursor <= rangeEnd.getTime(); cursor += 86_400_000) {
      byDate.set(new Date(cursor).toISOString().slice(0, 10), []);
    }

    if (this.featureEnabled) {
      const links = await this.prisma.timetableEntryGroup.findMany({
        where: { groupId: group.id, entry: { date: { gte: rangeStart, lte: rangeEnd } } },
        include: { entry: { include: { groups: { include: { group: true } } } } },
        orderBy: { entry: { startsAt: 'asc' } },
      });

      for (const link of links) {
        const entry = link.entry;
        const date = entry.date.toISOString().slice(0, 10);

        byDate.get(date)?.push({
          id: entry.id,
          start: entry.startsAt.toISOString(),
          end: entry.endsAt.toISOString(),
          timezone: TIMETABLE_TIMEZONE,
          title: entry.title,
          subjectCode: entry.subjectCode,
          type: entry.type,
          status: entry.status,
          teachers: TimetableService.mapRefs<TimetableTeacherDto>(entry.teachers, (ref) =>
            typeof ref.shortName === 'string'
              ? {
                  shortName: ref.shortName,
                  displayName: typeof ref.displayName === 'string' ? ref.displayName : null,
                }
              : null,
          ),
          rooms: TimetableService.mapRefs<TimetableRoomDto>(entry.rooms, (ref) =>
            typeof ref.shortName === 'string'
              ? {
                  shortName: ref.shortName,
                  longName: typeof ref.longName === 'string' ? ref.longName : null,
                }
              : null,
          ),
          groups: entry.groups.map((entryGroup) => TimetableService.mapGroup(entryGroup.group)),
          note: entry.note,
        });
      }
    }

    const hasAny = [...byDate.values()].some((entries) => entries.length > 0);
    const dataState: 'ready' | 'pending' | 'unavailable' = !this.featureEnabled
      ? 'unavailable'
      : lastSyncAt
        ? 'ready'
        : // Enabled but never synchronised: the worker has simply not run yet.
          // That is a temporary state the client can retry, not an error.
          hasAny
          ? 'ready'
          : 'pending';

    return {
      data: {
        group: TimetableService.mapGroup(group),
        days: [...byDate.entries()].map(([date, entries]): TimetableDayDto => ({ date, entries })),
      },
      lastSyncAt,
      stale: this.isStale(lastSyncAt),
      dataState,
    };
  }

  async getStatus(): Promise<TimetableStatusDto> {
    const [groupCount, lastGroupSyncAt, lastEntrySyncAt, lastRun] = await Promise.all([
      this.prisma.timetableGroup.count({ where: { active: true } }),
      this.lastSuccessful('groups'),
      this.lastSuccessful('entries'),
      this.prisma.timetableSyncRun.findFirst({
        where: { kind: 'entries', status: 'success' },
        orderBy: { finishedAt: 'desc' },
      }),
    ]);

    return {
      featureEnabled: this.featureEnabled,
      groupCount,
      lastGroupSyncAt: lastGroupSyncAt?.toISOString() ?? null,
      lastEntrySyncAt: lastEntrySyncAt?.toISOString() ?? null,
      dataStale: this.isStale(lastEntrySyncAt),
      coveredFrom: lastRun?.rangeFrom?.toISOString().slice(0, 10) ?? null,
      coveredTo: lastRun?.rangeTo?.toISOString().slice(0, 10) ?? null,
    };
  }
}
