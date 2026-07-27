import { Controller, Get, Inject, Param, Query } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { ApiResponse, buildMeta } from '../../common/dto/meta.dto';
import { ApiError } from '../../common/errors/api-error';
import { Locale, LocaleResolution } from '../../common/locale/locale';
import { RequestLocale } from '../../common/locale/locale.decorator';
import { parseWith } from '../../common/validation/query';
import { ENV } from '../../config/app-config.module';
import { Env } from '../../config/env.schema';
import { PublicCalendarService } from './public-calendar.service';
import {
  GoogleViewUrlDataDto,
  PublicCalendarDto,
  PublicCalendarEventDto,
} from './public-calendar.types';

const SLUG_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

@ApiTags('public-calendars')
@Controller({ path: 'calendars', version: '1' })
export class PublicCalendarController {
  constructor(
    private readonly calendars: PublicCalendarService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  private dateRangeSchema(locale: Locale) {
    const maxDays = this.env.PUBLIC_CALENDAR_API_MAX_RANGE_DAYS;
    const isoDate = z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/, 'expected YYYY-MM-DD')
      .refine((v) => !Number.isNaN(Date.parse(`${v}T00:00:00.000Z`)), 'invalid date');
    void locale;
    return z
      .object({ from: isoDate.optional(), to: isoDate.optional() })
      .transform((raw) => {
        const today = new Date().toISOString().slice(0, 10);
        const from = raw.from ?? today;
        const to = raw.to ?? new Date(Date.now() + maxDays * 86_400_000).toISOString().slice(0, 10);
        return { from, to };
      })
      .refine((r) => r.to >= r.from, 'to must not be before from')
      .refine(
        (r) =>
          (Date.parse(`${r.to}T00:00:00Z`) - Date.parse(`${r.from}T00:00:00Z`)) / 86_400_000 <=
          maxDays,
        `range must not exceed ${maxDays} days`,
      );
  }

  private parseCalendars(raw: unknown, locale: Locale): string[] {
    const values = Array.isArray(raw) ? raw : raw === undefined ? [] : [raw];
    const slugs: string[] = [];
    for (const v of values) {
      const s = String(v).trim();
      if (!SLUG_PATTERN.test(s)) {
        throw new ApiError('VALIDATION_FAILED', locale, [
          `calendar: invalid slug "${s.slice(0, 40)}"`,
        ]);
      }
      slugs.push(s);
    }
    const unique = [...new Set(slugs)];
    if (unique.length > this.env.PUBLIC_CALENDAR_API_MAX_CALENDARS) {
      throw new ApiError('VALIDATION_FAILED', locale, ['calendar: too many calendars requested']);
    }
    return unique;
  }

  private range(query: Record<string, unknown>, locale: Locale): { from: Date; to: Date } {
    const parsed = parseWith(this.dateRangeSchema(locale), query, locale);
    return {
      from: new Date(`${parsed.from}T00:00:00.000Z`),
      to: new Date(`${parsed.to}T23:59:59.999Z`),
    };
  }

  @Get()
  @ApiOperation({
    summary: 'List public calendars (read-only, synced from their public ICS feed).',
    description:
      'Only active, validated calendars that have synced at least once. The Google calendar id and feed URL are never exposed; each item carries a safe googleOpenUrl.',
  })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ type: [PublicCalendarDto] })
  async list(@RequestLocale() locale: LocaleResolution): Promise<ApiResponse<PublicCalendarDto[]>> {
    const { data, translationFallback } = await this.calendars.listCalendars(locale);
    return {
      data,
      meta: buildMeta({
        ...locale,
        translationFallback,
        featureEnabled: this.env.PUBLIC_CALENDAR_ENABLED,
      }),
    };
  }

  @Get('events')
  @ApiOperation({
    summary: 'Aggregated events across several selected public calendars.',
    description:
      'Pass one `calendar` slug per selected calendar. An empty selection returns an empty list (never "all calendars"). Each event carries calendarId and calendarSlug.',
  })
  @ApiQuery({ name: 'calendar', required: false, isArray: true, type: String })
  @ApiQuery({ name: 'from', required: false, description: 'YYYY-MM-DD' })
  @ApiQuery({ name: 'to', required: false, description: 'YYYY-MM-DD' })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ type: [PublicCalendarEventDto] })
  async aggregated(
    @RequestLocale() locale: LocaleResolution,
    @Query() query: Record<string, unknown>,
  ): Promise<ApiResponse<PublicCalendarEventDto[]>> {
    const slugs = this.parseCalendars(query.calendar, locale.resolvedLocale);
    const range = this.range(query, locale.resolvedLocale);
    const data = await this.calendars.getAggregatedEvents(slugs, range.from, range.to);
    return {
      data,
      meta: buildMeta({
        ...locale,
        translationFallback: false,
        from: range.from.toISOString().slice(0, 10),
        to: range.to.toISOString().slice(0, 10),
      }),
    };
  }

  @Get('google-view-url')
  @ApiOperation({
    summary: 'A combined calendar.google.com embed URL for the selected calendars.',
    description:
      "Server-constructed HTTPS URL (one src per calendar). This is a shared VIEW only — it never adds anything to a user's personal Google account.",
  })
  @ApiQuery({ name: 'calendar', required: true, isArray: true, type: String })
  @ApiOkResponse({ type: GoogleViewUrlDataDto })
  async googleViewUrl(
    @RequestLocale() locale: LocaleResolution,
    @Query() query: Record<string, unknown>,
  ): Promise<ApiResponse<GoogleViewUrlDataDto>> {
    const slugs = this.parseCalendars(query.calendar, locale.resolvedLocale);
    const url = await this.calendars.buildGoogleViewUrl(slugs, locale.resolvedLocale);
    return { data: { url }, meta: buildMeta({ ...locale, translationFallback: false }) };
  }

  @Get(':slug/events')
  @ApiOperation({ summary: 'Events of a single public calendar in a date range.' })
  @ApiQuery({ name: 'from', required: false, description: 'YYYY-MM-DD' })
  @ApiQuery({ name: 'to', required: false, description: 'YYYY-MM-DD' })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ type: [PublicCalendarEventDto] })
  async single(
    @RequestLocale() locale: LocaleResolution,
    @Param('slug') slug: string,
    @Query() query: Record<string, unknown>,
  ): Promise<ApiResponse<PublicCalendarEventDto[]>> {
    if (!SLUG_PATTERN.test(slug))
      throw new ApiError('PUBLIC_CALENDAR_NOT_FOUND', locale.resolvedLocale);
    const range = this.range(query, locale.resolvedLocale);
    const result = await this.calendars.getCalendarEvents(slug, range.from, range.to);
    if (!result) throw new ApiError('PUBLIC_CALENDAR_NOT_FOUND', locale.resolvedLocale);
    return {
      data: result.events,
      meta: buildMeta({
        ...locale,
        translationFallback: false,
        from: range.from.toISOString().slice(0, 10),
        to: range.to.toISOString().slice(0, 10),
        lastSuccessfulSyncAt: result.calendar.lastSuccessfulSyncAt,
        dataStale: result.calendar.dataStale,
      }),
    };
  }
}
