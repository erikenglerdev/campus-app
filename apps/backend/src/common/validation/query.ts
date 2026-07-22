import { z } from 'zod';
import { ApiError } from '../errors/api-error';
import { Locale } from '../locale/locale';
import { asString } from '../util/coerce';

/**
 * Query parsing helpers.
 *
 * Every list endpoint bounds its inputs. An unbounded `pageSize` or an
 * unbounded date range is an availability problem, not a convenience.
 */

export const MAX_PAGE_SIZE = 50;
export const DEFAULT_PAGE_SIZE = 20;
export const MAX_MENU_RANGE_DAYS = 31;
export const DEFAULT_MENU_RANGE_DAYS = 14;

export function parseWith<T>(schema: z.ZodType<T>, value: unknown, locale: Locale): T {
  const result = schema.safeParse(value);
  if (!result.success) {
    throw new ApiError(
      'VALIDATION_FAILED',
      locale,
      result.error.issues.map((issue) => `${issue.path.join('.') || '(query)'}: ${issue.message}`),
    );
  }
  return result.data;
}

export const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(MAX_PAGE_SIZE).default(DEFAULT_PAGE_SIZE),
});

/**
 * Splits the `channels` CSV.
 *
 * The distinction that matters: `undefined` (parameter absent) means "all
 * active channels", while `''` (present but empty) means "deliberately none".
 * Returning both the list and a presence flag keeps that explicit downstream.
 */
export function parseChannels(raw: unknown): {
  channels: string[];
  channelsParamPresent: boolean;
} {
  if (raw === undefined || raw === null) {
    return { channels: [], channelsParamPresent: false };
  }
  const value = Array.isArray(raw) ? raw.join(',') : asString(raw);
  return {
    channels: value
      .split(',')
      .map((entry) => entry.trim())
      .filter((entry) => entry.length > 0),
    channelsParamPresent: true,
  };
}

const isoDate = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'must be a date in YYYY-MM-DD format')
  .refine((value) => !Number.isNaN(Date.parse(`${value}T00:00:00Z`)), 'must be a valid date');

export const dateRangeSchema = z
  .object({ from: isoDate.optional(), to: isoDate.optional() })
  .transform((input) => {
    const from = input.from ?? new Date().toISOString().slice(0, 10);
    const to =
      input.to ??
      new Date(Date.parse(`${from}T00:00:00Z`) + DEFAULT_MENU_RANGE_DAYS * 86_400_000)
        .toISOString()
        .slice(0, 10);
    return { from, to };
  })
  .refine((range) => range.to >= range.from, {
    message: '`to` must not be earlier than `from`',
  })
  .refine(
    (range) =>
      (Date.parse(`${range.to}T00:00:00Z`) - Date.parse(`${range.from}T00:00:00Z`)) / 86_400_000 <=
      MAX_MENU_RANGE_DAYS,
    { message: `the range must not exceed ${MAX_MENU_RANGE_DAYS} days` },
  );
