import { EnvValidationError, validateEnv } from './env.schema';

const BASE = {
  DATABASE_URL: 'postgresql://user:pw@localhost:5432/db',
};

describe('validateEnv', () => {
  it('applies documented defaults', () => {
    const env = validateEnv({ ...BASE });
    expect(env.PORT).toBe(3000);
    expect(env.HOST).toBe('0.0.0.0');
    expect(env.CANTEEN_SYNC_CRON).toBe('0 */2 * * *');
    expect(env.CANTEEN_STALE_AFTER_MINUTES).toBe(240);
    expect(env.WORKER_TIME_ZONE).toBe('UTC');
    expect(env.LOG_LEVEL).toBe('info');
  });

  it('accepts an explicit IANA timezone for worker schedules', () => {
    expect(validateEnv({ ...BASE, WORKER_TIME_ZONE: 'Europe/Berlin' }).WORKER_TIME_ZONE).toBe(
      'Europe/Berlin',
    );
  });

  it('uses UTC when the worker timezone is present but empty', () => {
    expect(validateEnv({ ...BASE, WORKER_TIME_ZONE: '' }).WORKER_TIME_ZONE).toBe('UTC');
  });

  it('rejects an invalid worker timezone', () => {
    expect(() => validateEnv({ ...BASE, WORKER_TIME_ZONE: 'Europe/Berln' })).toThrow(
      EnvValidationError,
    );
  });

  it('rejects a non-PostgreSQL database url', () => {
    expect(() => validateEnv({ ...BASE, DATABASE_URL: 'mysql://x/y' })).toThrow(EnvValidationError);
  });

  it('requires a database url', () => {
    expect(() => validateEnv({})).toThrow(EnvValidationError);
  });

  it('never includes a secret value in the error message', () => {
    const secret = 'super-secret-password-value';
    try {
      validateEnv({ DATABASE_URL: `mysql://user:${secret}@h/db` });
      throw new Error('expected validation to fail');
    } catch (error) {
      expect((error as Error).message).not.toContain(secret);
      expect((error as Error).message).toContain('DATABASE_URL');
    }
  });

  it('parses a CORS allowlist into trimmed entries', () => {
    const env = validateEnv({
      ...BASE,
      CORS_ALLOWED_ORIGINS: 'https://a.example, https://b.example ,',
    });
    expect(env.CORS_ALLOWED_ORIGINS).toEqual(['https://a.example', 'https://b.example']);
  });

  it('rejects a CORS wildcard in production', () => {
    expect(() =>
      validateEnv({
        ...BASE,
        NODE_ENV: 'production',
        CORS_ALLOWED_ORIGINS: '*',
      }),
    ).toThrow(/must not contain/);
  });

  it('allows a wildcard outside production', () => {
    const env = validateEnv({
      ...BASE,
      NODE_ENV: 'development',
      CORS_ALLOWED_ORIGINS: '*',
    });
    expect(env.CORS_ALLOWED_ORIGINS).toEqual(['*']);
  });

  it('treats an empty variable as unset and uses the default', () => {
    const env = validateEnv({ ...BASE, PORT: '' });
    expect(env.PORT).toBe(3000);
  });

  it('keeps an intentionally empty Strapi token without failing', () => {
    const env = validateEnv({ ...BASE, STRAPI_API_TOKEN: '' });
    expect(env.STRAPI_API_TOKEN).toBe('');
  });

  it('rejects a Strapi base url that is not http(s)', () => {
    expect(() => validateEnv({ ...BASE, STRAPI_BASE_URL: 'ftp://cms.example' })).toThrow(
      EnvValidationError,
    );
  });

  it('coerces and range-checks numeric settings', () => {
    expect(() => validateEnv({ ...BASE, PORT: '70000' })).toThrow();
    expect(validateEnv({ ...BASE, PORT: '8080' }).PORT).toBe(8080);
  });

  it('parses boolean-ish flags', () => {
    expect(validateEnv({ ...BASE, CANTEEN_SYNC_ON_BOOT: 'true' }).CANTEEN_SYNC_ON_BOOT).toBe(true);
    expect(validateEnv({ ...BASE, CANTEEN_SYNC_ON_BOOT: '0' }).CANTEEN_SYNC_ON_BOOT).toBe(false);
  });
});
