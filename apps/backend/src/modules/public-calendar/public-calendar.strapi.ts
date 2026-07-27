import { z } from 'zod';
import { tryExtractCalendarId } from './google-calendar-url';
import { CalendarDefinition } from './public-calendar.types';

/**
 * Validation of the editorial calendar definitions coming from Strapi.
 *
 * This runs at the BACKEND trust boundary: even though Strapi's own validation
 * should already reject a bad share URL, the worker re-validates every field
 * here and re-derives the calendar id from the share link. A single invalid
 * entry is dropped (and counted), never taking the rest of the catalogue down.
 */

const SLUG_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const COLOR_PATTERN = /^#[0-9A-Fa-f]{6}$/;

/** Strapi 5 returns flat attributes. Unknown extra keys are ignored. */
const strapiEntrySchema = z
  .object({
    slug: z.string(),
    name: z.string().min(1),
    description: z.string().nullish(),
    googleShareUrl: z.string(),
    colorHex: z.string(),
    iconKey: z.string().min(1),
    sortOrder: z.coerce.number().int().default(0),
    isActive: z.boolean().default(true),
    defaultSubscribed: z.boolean().default(false),
    attribution: z.string().nullish(),
    showDescription: z.boolean().default(false),
    showLocation: z.boolean().default(false),
    timeZone: z.string().nullish(),
  })
  .passthrough();

export type StrapiEntry = z.infer<typeof strapiEntrySchema>;

function isValidTimeZone(tz: string): boolean {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

export interface CatalogValidationResult {
  definitions: CalendarDefinition[];
  received: number;
  rejected: number;
}

/**
 * Validates the canonical (German) catalogue, overlaying English translations
 * keyed by the non-localised slug.
 */
export function validateCatalog(
  deEntries: unknown[],
  enEntries: unknown[],
  defaultFallbackTimeZone = 'Europe/Berlin',
): CatalogValidationResult {
  const enBySlug = new Map<string, StrapiEntry>();
  for (const raw of enEntries) {
    const parsed = strapiEntrySchema.safeParse(raw);
    if (parsed.success && SLUG_PATTERN.test(parsed.data.slug)) {
      enBySlug.set(parsed.data.slug, parsed.data);
    }
  }

  const definitions: CalendarDefinition[] = [];
  let rejected = 0;

  for (const raw of deEntries) {
    const parsed = strapiEntrySchema.safeParse(raw);
    if (!parsed.success) {
      rejected += 1;
      continue;
    }
    const entry = parsed.data;

    if (!SLUG_PATTERN.test(entry.slug) || !COLOR_PATTERN.test(entry.colorHex)) {
      rejected += 1;
      continue;
    }
    const extracted = tryExtractCalendarId(entry.googleShareUrl);
    if (!extracted.ok) {
      rejected += 1;
      continue;
    }

    const timeZone =
      entry.timeZone && isValidTimeZone(entry.timeZone) ? entry.timeZone : defaultFallbackTimeZone;
    const en = enBySlug.get(entry.slug);

    definitions.push({
      slug: entry.slug,
      googleCalendarId: extracted.calendarId,
      nameDe: entry.name,
      nameEn: en?.name ?? null,
      descriptionDe: entry.description ?? null,
      descriptionEn: en?.description ?? null,
      colorHex: entry.colorHex.toUpperCase(),
      iconKey: entry.iconKey,
      sortOrder: entry.sortOrder,
      defaultSubscribed: entry.defaultSubscribed,
      attributionDe: entry.attribution ?? null,
      attributionEn: en?.attribution ?? null,
      showDescription: entry.showDescription,
      showLocation: entry.showLocation,
      fallbackTimeZone: timeZone,
    });
  }

  return { definitions, received: deEntries.length, rejected };
}
