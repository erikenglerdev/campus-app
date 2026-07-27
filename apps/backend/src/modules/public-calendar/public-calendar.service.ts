import { Inject, Injectable } from '@nestjs/common';
import { ENV } from '../../config/app-config.module';
import { Env } from '../../config/env.schema';
import { ApiError } from '../../common/errors/api-error';
import { Locale, LocaleResolution } from '../../common/locale/locale';
import { PrismaService } from '../../prisma/prisma.service';
import { buildCombinedEmbedUrl, buildSingleOpenUrl } from './google-calendar-url';
import { PublicCalendarDto, PublicCalendarEventDto } from './public-calendar.types';

/**
 * Read model for the public calendar API. Serves ONLY calendars that are
 * active, validated and have at least one successful ICS sync. The
 * server-internal Google calendar id and the feed URL are never exposed; the
 * app receives only stable slugs/UUIDs and a safe `googleOpenUrl`.
 */
@Injectable()
export class PublicCalendarService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /** An operational status that may be served to clients. */
  private static readonly SERVABLE = ['ready', 'stale'];

  private servableWhere() {
    return {
      isActive: true,
      operationalStatus: { in: PublicCalendarService.SERVABLE },
      lastSuccessfulSyncAt: { not: null },
    };
  }

  private isStale(status: string, lastSuccessfulSyncAt: Date | null): boolean {
    if (status === 'stale') return true;
    if (!lastSuccessfulSyncAt) return true;
    const ageMinutes = (Date.now() - lastSuccessfulSyncAt.getTime()) / 60_000;
    return ageMinutes > this.env.PUBLIC_CALENDAR_STALE_AFTER_MINUTES;
  }

  private localise(
    locale: Locale,
    de: string,
    en: string | null,
  ): { value: string; fellBack: boolean } {
    if (locale === 'en') {
      if (en && en.trim().length > 0) return { value: en, fellBack: false };
      return { value: de, fellBack: true };
    }
    return { value: de, fellBack: false };
  }

  async listCalendars(
    locale: LocaleResolution,
  ): Promise<{ data: PublicCalendarDto[]; translationFallback: boolean }> {
    const rows = await this.prisma.publicCalendar.findMany({
      where: this.servableWhere(),
      orderBy: [{ sortOrder: 'asc' }, { slug: 'asc' }],
    });
    let translationFallback = false;
    const data = rows.map((row) => {
      const name = this.localise(locale.resolvedLocale, row.nameDe, row.nameEn);
      const description = this.localise(
        locale.resolvedLocale,
        row.descriptionDe ?? '',
        row.descriptionEn,
      );
      const attribution = this.localise(
        locale.resolvedLocale,
        row.attributionDe ?? '',
        row.attributionEn,
      );
      if (
        name.fellBack ||
        (row.descriptionEn === null && row.descriptionDe) ||
        attribution.fellBack
      ) {
        if (locale.resolvedLocale === 'en')
          translationFallback = translationFallback || name.fellBack;
      }
      const stale = this.isStale(row.operationalStatus, row.lastSuccessfulSyncAt);
      return {
        id: row.id,
        slug: row.slug,
        name: name.value,
        description: (row.descriptionDe ?? row.descriptionEn) ? description.value : null,
        colorHex: row.colorHex,
        iconKey: row.iconKey,
        sortOrder: row.sortOrder,
        defaultSubscribed: row.defaultSubscribed,
        attribution: (row.attributionDe ?? row.attributionEn) ? attribution.value : null,
        dataState: stale ? 'stale' : 'ready',
        lastSuccessfulSyncAt: row.lastSuccessfulSyncAt?.toISOString() ?? null,
        dataStale: stale,
        googleOpenUrl: buildSingleOpenUrl(row.googleCalendarId),
      } satisfies PublicCalendarDto;
    });
    return { data, translationFallback };
  }

  private toEventDto(
    row: {
      id: string;
      calendarId: string;
      title: string;
      description: string | null;
      location: string | null;
      startsAt: Date;
      endsAt: Date;
      allDay: boolean;
      status: string;
    },
    slug: string,
  ): PublicCalendarEventDto {
    return {
      id: row.id,
      calendarId: row.calendarId,
      calendarSlug: slug,
      title: row.title,
      description: row.description,
      location: row.location,
      start: row.startsAt.toISOString(),
      end: row.endsAt.toISOString(),
      allDay: row.allDay,
      status: row.status,
    };
  }

  async getCalendarEvents(
    slug: string,
    from: Date,
    to: Date,
  ): Promise<{ calendar: PublicCalendarDto; events: PublicCalendarEventDto[] } | null> {
    const row = await this.prisma.publicCalendar.findFirst({
      where: { slug, ...this.servableWhere() },
    });
    if (!row) return null;
    const events = await this.prisma.publicCalendarEvent.findMany({
      where: { calendarId: row.id, startsAt: { gte: from, lte: to } },
      orderBy: [{ startsAt: 'asc' }, { id: 'asc' }],
    });
    const stale = this.isStale(row.operationalStatus, row.lastSuccessfulSyncAt);
    return {
      calendar: {
        id: row.id,
        slug: row.slug,
        name: row.nameDe,
        description: row.descriptionDe,
        colorHex: row.colorHex,
        iconKey: row.iconKey,
        sortOrder: row.sortOrder,
        defaultSubscribed: row.defaultSubscribed,
        attribution: row.attributionDe,
        dataState: stale ? 'stale' : 'ready',
        lastSuccessfulSyncAt: row.lastSuccessfulSyncAt?.toISOString() ?? null,
        dataStale: stale,
        googleOpenUrl: buildSingleOpenUrl(row.googleCalendarId),
      },
      events: events.map((e) => this.toEventDto(e, slug)),
    };
  }

  /** Aggregated events across the selected calendars. Empty selection → []. */
  async getAggregatedEvents(
    slugs: string[],
    from: Date,
    to: Date,
  ): Promise<PublicCalendarEventDto[]> {
    if (slugs.length === 0) return [];
    const rows = await this.prisma.publicCalendar.findMany({
      where: { slug: { in: slugs }, ...this.servableWhere() },
      select: { id: true, slug: true },
    });
    if (rows.length === 0) return [];
    const slugById = new Map(rows.map((r) => [r.id, r.slug]));
    const events = await this.prisma.publicCalendarEvent.findMany({
      where: { calendarId: { in: rows.map((r) => r.id) }, startsAt: { gte: from, lte: to } },
      orderBy: [{ startsAt: 'asc' }, { calendarId: 'asc' }, { id: 'asc' }],
    });
    return events.map((e) => this.toEventDto(e, slugById.get(e.calendarId) ?? ''));
  }

  /** Resolves servable slugs to a combined Google embed URL. */
  async buildGoogleViewUrl(slugs: string[], locale: Locale): Promise<string> {
    const unique = [...new Set(slugs)];
    if (unique.length === 0) {
      throw new ApiError('VALIDATION_FAILED', locale, [
        'calendar: at least one calendar is required',
      ]);
    }
    if (unique.length > this.env.PUBLIC_CALENDAR_API_MAX_CALENDARS) {
      throw new ApiError('VALIDATION_FAILED', locale, ['calendar: too many calendars requested']);
    }
    const rows = await this.prisma.publicCalendar.findMany({
      where: { slug: { in: unique }, ...this.servableWhere() },
      orderBy: [{ sortOrder: 'asc' }, { slug: 'asc' }],
      select: { googleCalendarId: true },
    });
    if (rows.length === 0) {
      throw new ApiError('PUBLIC_CALENDAR_NOT_FOUND', locale);
    }
    return buildCombinedEmbedUrl(
      rows.map((r) => r.googleCalendarId),
      this.env.PUBLIC_CALENDAR_FALLBACK_TIME_ZONE,
    );
  }
}
