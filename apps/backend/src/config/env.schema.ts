import { z } from 'zod';

/**
 * Single source of truth for every environment variable the backend reads.
 *
 * Environment is the ONLY thing that differs between DEV and PROD — there is no
 * environment-specific source code and no hardcoded host anywhere. Validation
 * happens once at boot so a misconfigured deployment fails immediately and
 * loudly instead of erroring on the first request.
 */

const booleanFromEnv = z
  .enum(['true', 'false', '1', '0'])
  .transform((value) => value === 'true' || value === '1');

const csv = z.string().transform((value) =>
  value
    .split(',')
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0),
);

export const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),

  // --- HTTP server ---------------------------------------------------------
  HOST: z.string().min(1).default('0.0.0.0'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),

  /**
   * Comma-separated allowlist. A wildcard is rejected in production so a
   * permissive local default can never be promoted to a live deployment.
   */
  // Zod 4: `.default()` takes the OUTPUT type, i.e. the already-split array.
  CORS_ALLOWED_ORIGINS: csv.default(['http://localhost:3000']),

  // --- Database ------------------------------------------------------------
  DATABASE_URL: z
    .string()
    .min(1)
    .refine(
      (value) => value.startsWith('postgresql://') || value.startsWith('postgres://'),
      'DATABASE_URL must be a PostgreSQL connection string',
    ),

  // --- Strapi --------------------------------------------------------------
  /** Never a source constant — the CMS address is configuration, always. */
  STRAPI_BASE_URL: z.url({ protocol: /^https?$/ }).default('http://127.0.0.1:1337'),
  /**
   * Server-side READ-ONLY token. Optional so the stack can boot before the
   * token exists; /health/ready then reports strapi as degraded, which is the
   * honest signal rather than a hidden failure.
   */
  STRAPI_API_TOKEN: z.string().default(''),
  STRAPI_TIMEOUT_MS: z.coerce.number().int().min(500).max(60_000).default(10_000),
  STRAPI_RETRY_ATTEMPTS: z.coerce.number().int().min(0).max(5).default(2),

  // --- Canteen source ------------------------------------------------------
  CANTEEN_SOURCE_URL: z.url().default('https://meine-mensa.de/api/food_plans'),
  CANTEEN_HTTP_TIMEOUT_MS: z.coerce.number().int().min(1000).max(120_000).default(15_000),
  CANTEEN_RETRY_ATTEMPTS: z.coerce.number().int().min(0).max(5).default(3),
  /** Politeness delay between per-canteen requests, in milliseconds. */
  CANTEEN_REQUEST_SPACING_MS: z.coerce.number().int().min(0).max(60_000).default(1_000),
  /** Every two hours. Deliberately not aggressive. */
  CANTEEN_SYNC_CRON: z.string().min(1).default('0 */2 * * *'),
  CANTEEN_SYNC_ON_BOOT: booleanFromEnv.default(false),
  /** Data older than this is reported to the client as `dataStale`. */
  CANTEEN_STALE_AFTER_MINUTES: z.coerce.number().int().min(5).max(10_080).default(240),
  /** How far ahead a sync fetches: current + next week. */
  CANTEEN_SYNC_DAYS_AHEAD: z.coerce.number().int().min(1).max(60).default(14),

  // --- WebUntis timetable --------------------------------------------------
  /**
   * OFF by default, on purpose. The source is an internal interface of a
   * third party's public web UI, and automated use is not cleared yet. The
   * feature ships complete but dormant until that is a deliberate decision.
   */
  WEBUNTIS_ENABLED: booleanFromEnv.default(false),
  WEBUNTIS_BASE_URL: z.url().default('https://hsa.webuntis.com/WebUntis/api/rest/view/v1'),
  /**
   * Identifies the tenant for the anonymous public view. Not a credential, but
   * still server-side configuration: it must never reach the app.
   */
  WEBUNTIS_ANONYMOUS_SCHOOL: z.string().min(1).default('hsa'),
  WEBUNTIS_HTTP_TIMEOUT_MS: z.coerce.number().int().min(1000).max(120_000).default(20_000),
  WEBUNTIS_RETRY_ATTEMPTS: z.coerce.number().int().min(0).max(5).default(3),
  /** Politeness delay between consecutive upstream requests. */
  WEBUNTIS_REQUEST_SPACING_MS: z.coerce.number().int().min(0).max(60_000).default(1_500),
  /** Largest response we are willing to buffer, as a crude runaway guard. */
  WEBUNTIS_MAX_RESPONSE_BYTES: z.coerce
    .number()
    .int()
    .min(64_000)
    .max(64_000_000)
    .default(16_000_000),
  /** The catalogue is near-static; twice a day is already generous. */
  WEBUNTIS_GROUP_SYNC_CRON: z.string().min(1).default('0 3,15 * * *'),
  /**
   * Hourly. Entries for ALL groups arrive in ONE request, so this is 24
   * upstream calls a day in total — a timetable does not change often enough
   * to justify more, and automated use is not cleared yet.
   */
  WEBUNTIS_ENTRY_SYNC_CRON: z.string().min(1).default('0 * * * *'),
  WEBUNTIS_SYNC_ON_BOOT: booleanFromEnv.default(false),
  WEBUNTIS_LOOKBACK_DAYS: z.coerce.number().int().min(0).max(90).default(7),
  WEBUNTIS_LOOKAHEAD_DAYS: z.coerce.number().int().min(1).max(180).default(28),
  WEBUNTIS_STALE_AFTER_MINUTES: z.coerce.number().int().min(5).max(10_080).default(180),

  // --- Observability -------------------------------------------------------
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
  /** Pretty console output for humans; JSON is the default and the server format. */
  LOG_PRETTY: booleanFromEnv.default(false),
});

export type Env = z.infer<typeof envSchema>;

export class EnvValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'EnvValidationError';
  }
}

export function validateEnv(raw: NodeJS.ProcessEnv): Env {
  // Empty strings are treated as "unset" so an empty compose variable falls
  // through to the documented default instead of failing validation.
  const cleaned: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(raw)) {
    if (value !== undefined && value !== '') {
      cleaned[key] = value;
    }
  }
  // STRAPI_API_TOKEN is legitimately empty-but-present; keep it explicit.
  if (raw.STRAPI_API_TOKEN !== undefined) {
    cleaned['STRAPI_API_TOKEN'] = raw.STRAPI_API_TOKEN;
  }

  const parsed = envSchema.safeParse(cleaned);

  if (!parsed.success) {
    // Report the offending KEYS and reasons, never the values — a validation
    // error must not print a database password into the logs.
    const issues = parsed.error.issues
      .map((issue) => `  - ${issue.path.join('.') || '(root)'}: ${issue.message}`)
      .join('\n');
    throw new EnvValidationError(`Invalid environment configuration:\n${issues}`);
  }

  const env = parsed.data;

  if (env.NODE_ENV === 'production') {
    if (env.CORS_ALLOWED_ORIGINS.includes('*')) {
      throw new EnvValidationError(
        'CORS_ALLOWED_ORIGINS must not contain "*" when NODE_ENV=production.',
      );
    }
    if (env.CORS_ALLOWED_ORIGINS.length === 0) {
      throw new EnvValidationError(
        'CORS_ALLOWED_ORIGINS must list at least one origin when NODE_ENV=production.',
      );
    }
  }

  return env;
}
