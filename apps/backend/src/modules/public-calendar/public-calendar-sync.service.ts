import { createHash } from 'node:crypto';
import { Inject, Injectable, Logger } from '@nestjs/common';
import { ENV } from '../../config/app-config.module';
import { Env } from '../../config/env.schema';
import { PrismaService } from '../../prisma/prisma.service';
import { StrapiClient, StrapiListResponse } from '../strapi/strapi.client';
import { GooglePublicIcsClient, IcsClientError } from './google-public-ics.client';
import { IcsParseError, ParsedEvent, parseIcs } from './ics-parser';
import { CalendarDefinition } from './public-calendar.types';
import { validateCatalog } from './public-calendar.strapi';

/**
 * Public-calendar synchronisation.
 *
 * Two independent jobs, both governed by the project's core rule: a failed,
 * invalid or unexpectedly empty upstream response NEVER deletes stored data.
 *
 *  - `syncCatalog()` mirrors the PUBLISHED, VALIDATED Strapi definitions into
 *    the operational read-model. Strapi stays the canonical editorial source;
 *    Postgres only ever holds the last fully-validated snapshot.
 *  - `syncEvents()` downloads each active calendar's public ICS feed, expands
 *    it within a bounded window and reconciles it transactionally. A calendar
 *    becomes publicly visible only after validation AND a first successful sync.
 */

export interface CatalogOutcome {
  status: 'success' | 'empty' | 'failed';
  received: number;
  accepted: number;
  rejected: number;
  written: number;
  deactivated: number;
  errorCode?: string;
}

export interface EventOutcome {
  slug: string;
  status: 'success' | 'notModified' | 'empty' | 'stale' | 'revoked' | 'failed';
  received: number;
  written: number;
  removed: number;
  errorCode?: string;
}

@Injectable()
export class PublicCalendarSyncService {
  private readonly logger = new Logger(PublicCalendarSyncService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly strapi: StrapiClient,
    private readonly ics: GooglePublicIcsClient,
    @Inject(ENV) private readonly env: Env,
  ) {}

  // -------------------------------------------------------------------------
  // Catalogue
  // -------------------------------------------------------------------------

  async syncCatalog(): Promise<CatalogOutcome> {
    const run = await this.prisma.publicCalendarSyncRun.create({
      data: { kind: 'catalog', status: 'running' },
    });
    try {
      const de = await this.fetchAll('de');
      const en = await this.fetchAll('en');
      const { definitions, received, rejected } = validateCatalog(
        de,
        en,
        this.env.PUBLIC_CALENDAR_FALLBACK_TIME_ZONE,
      );

      // An empty (or fully-rejected) catalogue is treated as suspect: it keeps
      // the last good read-model instead of deactivating every calendar.
      if (definitions.length === 0) {
        await this.finishRun(run.id, {
          status: 'empty',
          eventsReceived: received,
          recordsRejected: rejected,
          errorMessage: 'empty or fully-rejected catalogue; existing definitions kept',
        });
        this.logger.warn('Public-calendar catalogue came back empty; existing definitions kept');
        return { status: 'empty', received, accepted: 0, rejected, written: 0, deactivated: 0 };
      }

      const now = new Date();
      await this.prisma.$transaction(async (tx) => {
        for (const def of definitions) {
          await tx.publicCalendar.upsert({
            where: { slug: def.slug },
            create: { ...this.toRow(def), operationalStatus: 'pending', lastCatalogSyncAt: now },
            update: { ...this.toRow(def), isActive: true, lastCatalogSyncAt: now },
          });
        }
      });

      // Only after a complete, non-empty success may a calendar that Strapi no
      // longer publishes be retired. It is deactivated, never deleted.
      const retired = await this.prisma.publicCalendar.updateMany({
        where: { isActive: true, slug: { notIn: definitions.map((d) => d.slug) } },
        data: { isActive: false },
      });

      await this.finishRun(run.id, {
        status: 'success',
        eventsReceived: received,
        recordsAccepted: definitions.length,
        recordsRejected: rejected,
        recordsWritten: definitions.length,
        recordsRemoved: retired.count,
      });
      this.logger.log(
        `Public-calendar catalogue: ${definitions.length} upserted, ${retired.count} retired, ${rejected} rejected`,
      );
      return {
        status: 'success',
        received,
        accepted: definitions.length,
        rejected,
        written: definitions.length,
        deactivated: retired.count,
      };
    } catch (error) {
      const code = error instanceof Error ? error.name : 'unknown';
      await this.finishRun(run.id, {
        status: 'failed',
        errorCode: 'strapiUnavailable',
        errorMessage: this.redact(error),
      });
      this.logger.warn(
        `Public-calendar catalogue sync failed (${code}); existing definitions kept`,
      );
      return {
        status: 'failed',
        received: 0,
        accepted: 0,
        rejected: 0,
        written: 0,
        deactivated: 0,
        errorCode: code,
      };
    }
  }

  private toRow(def: CalendarDefinition) {
    return {
      slug: def.slug,
      googleCalendarId: def.googleCalendarId,
      nameDe: def.nameDe,
      nameEn: def.nameEn,
      descriptionDe: def.descriptionDe,
      descriptionEn: def.descriptionEn,
      colorHex: def.colorHex,
      iconKey: def.iconKey,
      sortOrder: def.sortOrder,
      defaultSubscribed: def.defaultSubscribed,
      attributionDe: def.attributionDe,
      attributionEn: def.attributionEn,
      showDescription: def.showDescription,
      showLocation: def.showLocation,
      fallbackTimeZone: def.fallbackTimeZone,
    };
  }

  private async fetchAll(locale: 'de' | 'en'): Promise<unknown[]> {
    const collected: unknown[] = [];
    let page = 1;
    for (;;) {
      const response = await this.strapi.get<StrapiListResponse<unknown>>('/api/public-calendars', {
        filters: { isActive: { $eq: true } },
        sort: ['sortOrder:asc', 'slug:asc'],
        pagination: { page, pageSize: 100 },
        locale,
      });
      collected.push(...response.data);
      const pageCount = response.meta?.pagination?.pageCount ?? 1;
      if (page >= pageCount) break;
      page += 1;
    }
    return collected;
  }

  // -------------------------------------------------------------------------
  // Events
  // -------------------------------------------------------------------------

  window(now = new Date()): { from: Date; to: Date } {
    const day = 86_400_000;
    return {
      from: new Date(now.getTime() - this.env.PUBLIC_CALENDAR_LOOKBACK_DAYS * day),
      to: new Date(now.getTime() + this.env.PUBLIC_CALENDAR_LOOKAHEAD_DAYS * day),
    };
  }

  async syncEvents(): Promise<EventOutcome[]> {
    const calendars = await this.prisma.publicCalendar.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
    });
    const outcomes: EventOutcome[] = [];
    for (const calendar of calendars) {
      // Each calendar is isolated: one failing feed never stops the others.
      outcomes.push(await this.syncCalendarEvents(calendar.slug));
    }
    return outcomes;
  }

  async syncCalendarEvents(slug: string): Promise<EventOutcome> {
    const calendar = await this.prisma.publicCalendar.findUnique({ where: { slug } });
    if (!calendar || !calendar.isActive) {
      return {
        slug,
        status: 'failed',
        received: 0,
        written: 0,
        removed: 0,
        errorCode: 'unknownCalendar',
      };
    }

    const win = this.window();
    const run = await this.prisma.publicCalendarSyncRun.create({
      data: {
        kind: 'events',
        status: 'running',
        calendarSlug: slug,
        rangeFrom: win.from,
        rangeTo: win.to,
      },
    });

    try {
      const fetched = await this.ics.fetchCalendar(calendar.googleCalendarId, {
        etag: calendar.lastEtag,
        lastModified: calendar.lastModified,
      });

      if (fetched.kind === 'notModified') {
        await this.prisma.publicCalendar.update({
          where: { id: calendar.id },
          data: { lastSuccessfulSyncAt: new Date(), operationalStatus: 'ready' },
        });
        await this.finishRun(run.id, { status: 'notModified' });
        return { slug, status: 'notModified', received: 0, written: 0, removed: 0 };
      }

      const contentHash = createHash('sha256').update(fetched.body).digest('hex');
      if (contentHash === calendar.lastContentHash) {
        await this.prisma.publicCalendar.update({
          where: { id: calendar.id },
          data: {
            lastSuccessfulSyncAt: new Date(),
            operationalStatus: 'ready',
            lastEtag: fetched.etag,
            lastModified: fetched.lastModified,
          },
        });
        await this.finishRun(run.id, { status: 'notModified', feedBytes: fetched.body.length });
        return { slug, status: 'notModified', received: 0, written: 0, removed: 0 };
      }

      const events = parseIcs(fetched.body, {
        windowStart: win.from,
        windowEnd: win.to,
        fallbackTimeZone: calendar.fallbackTimeZone,
        includeDescription: calendar.showDescription,
        includeLocation: calendar.showLocation,
        maxEvents: this.env.PUBLIC_CALENDAR_MAX_EVENTS,
        maxOccurrences: this.env.PUBLIC_CALENDAR_MAX_OCCURRENCES,
        maxOccurrencesPerEvent: this.env.PUBLIC_CALENDAR_MAX_OCCURRENCES_PER_EVENT,
        maxTextLength: this.env.PUBLIC_CALENDAR_MAX_TEXT_LENGTH,
      });

      const removed = await this.reconcile(calendar.id, win, events);

      await this.prisma.publicCalendar.update({
        where: { id: calendar.id },
        data: {
          operationalStatus: 'ready',
          lastEtag: fetched.etag,
          lastModified: fetched.lastModified,
          lastContentHash: contentHash,
          lastSuccessfulSyncAt: new Date(),
        },
      });
      await this.finishRun(run.id, {
        status: events.length === 0 ? 'empty' : 'success',
        feedBytes: fetched.body.length,
        eventsExpanded: events.length,
        recordsWritten: events.length,
        recordsRemoved: removed,
      });
      return {
        slug,
        status: events.length === 0 ? 'empty' : 'success',
        received: events.length,
        written: events.length,
        removed,
      };
    } catch (error) {
      return this.handleEventFailure(
        run.id,
        calendar.id,
        slug,
        calendar.operationalStatus,
        calendar.lastSuccessfulSyncAt,
        error,
      );
    }
  }

  /** Transactional upsert + windowed, non-destructive reconciliation. */
  private async reconcile(
    calendarId: string,
    win: { from: Date; to: Date },
    events: ParsedEvent[],
  ): Promise<number> {
    return this.prisma.$transaction(
      async (tx) => {
        const keptKeys: string[] = [];
        const now = new Date();
        for (const e of events) {
          await tx.publicCalendarEvent.upsert({
            where: { calendarId_occurrenceKey: { calendarId, occurrenceKey: e.occurrenceKey } },
            create: {
              calendarId,
              occurrenceKey: e.occurrenceKey,
              uid: e.uid,
              recurrenceId: e.recurrenceId,
              sequence: e.sequence,
              title: e.title,
              description: e.description,
              location: e.location,
              startsAt: e.start,
              endsAt: e.end,
              allDay: e.allDay,
              status: e.status,
              sourceUpdatedAt: e.sourceUpdatedAt,
            },
            update: {
              uid: e.uid,
              recurrenceId: e.recurrenceId,
              sequence: e.sequence,
              title: e.title,
              description: e.description,
              location: e.location,
              startsAt: e.start,
              endsAt: e.end,
              allDay: e.allDay,
              status: e.status,
              sourceUpdatedAt: e.sourceUpdatedAt,
              lastSeenAt: now,
            },
          });
          keptKeys.push(e.occurrenceKey);
        }
        // Delete only WITHIN the confirmed window and only rows not seen this run.
        const removed = await tx.publicCalendarEvent.deleteMany({
          where: {
            calendarId,
            startsAt: { gte: win.from, lte: win.to },
            occurrenceKey: { notIn: keptKeys.length > 0 ? keptKeys : ['__none__'] },
          },
        });
        return removed.count;
      },
      { timeout: 120_000, maxWait: 10_000 },
    );
  }

  private async handleEventFailure(
    runId: string,
    calendarId: string,
    slug: string,
    currentStatus: string,
    hadSuccess: Date | null,
    error: unknown,
  ): Promise<EventOutcome> {
    let errorCode = 'unknown';
    let nextStatus = currentStatus;
    let runStatus: EventOutcome['status'] = 'failed';

    if (error instanceof IcsClientError) {
      errorCode = error.kind;
      if (error.kind === 'feedNotFound' || error.kind === 'permissionRevoked') {
        // The feed is gone / no longer public: block it and clear its events so
        // stale data is not served indefinitely.
        nextStatus = error.kind === 'feedNotFound' ? 'unavailable' : 'revoked';
        runStatus = 'revoked';
        await this.prisma.publicCalendarEvent.deleteMany({ where: { calendarId } });
      } else {
        // Temporary transport error: keep the last good events, mark stale.
        nextStatus = hadSuccess ? 'stale' : 'pending';
        runStatus = 'stale';
      }
    } else if (error instanceof IcsParseError) {
      errorCode = error.kind;
      // Corrupt / oversized / recurrence-bomb: never destructive. Keep events.
      nextStatus = hadSuccess ? 'stale' : 'invalid';
      runStatus = 'stale';
    }

    await this.prisma.publicCalendar.update({
      where: { id: calendarId },
      data: { operationalStatus: nextStatus },
    });
    await this.finishRun(runId, { status: runStatus, errorCode, errorMessage: this.redact(error) });
    this.logger.warn(
      `Public-calendar events sync for "${slug}" -> ${runStatus} (${errorCode}); data kept`,
    );
    return { slug, status: runStatus, received: 0, written: 0, removed: 0, errorCode };
  }

  // -------------------------------------------------------------------------

  private async finishRun(
    id: string,
    data: {
      status: string;
      feedBytes?: number;
      eventsReceived?: number;
      eventsExpanded?: number;
      recordsAccepted?: number;
      recordsRejected?: number;
      recordsWritten?: number;
      recordsRemoved?: number;
      errorCode?: string;
      errorMessage?: string;
    },
  ): Promise<void> {
    await this.prisma.publicCalendarSyncRun.update({
      where: { id },
      data: { ...data, finishedAt: new Date() },
    });
  }

  private redact(error: unknown): string {
    if (error instanceof Error) return `${error.name}`.slice(0, 120);
    return 'unknown error';
  }

  async lastSuccessfulCatalogAt(): Promise<Date | null> {
    const run = await this.prisma.publicCalendarSyncRun.findFirst({
      where: { kind: 'catalog', status: 'success', finishedAt: { not: null } },
      orderBy: { finishedAt: 'desc' },
    });
    return run?.finishedAt ?? null;
  }
}
