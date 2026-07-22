import { redactValue } from './json-logger.service';

describe('redactValue', () => {
  it('redacts credentials embedded in a connection string', () => {
    const out = redactValue('postgresql://campus_app:s3cr3t-pw@db:5432/campus') as string;
    expect(out).not.toContain('s3cr3t-pw');
    expect(out).toContain('campus_app');
    expect(out).toContain('[redacted]');
  });

  it('redacts a bearer token in free text', () => {
    const out = redactValue('called with Bearer abcdef0123456789ABC') as string;
    expect(out).not.toContain('abcdef0123456789ABC');
    expect(out).toContain('[redacted]');
  });

  it('redacts values of sensitive keys regardless of case', () => {
    const out = redactValue({
      STRAPI_API_TOKEN: 'tok_live_123',
      Password: 'hunter2',
      apiKey: 'k-1',
      authorization: 'Bearer x',
      encryptionKey: 'e',
      safe: 'visible',
    }) as Record<string, unknown>;

    expect(out['STRAPI_API_TOKEN']).toBe('[redacted]');
    expect(out['Password']).toBe('[redacted]');
    expect(out['apiKey']).toBe('[redacted]');
    expect(out['authorization']).toBe('[redacted]');
    expect(out['encryptionKey']).toBe('[redacted]');
    expect(out['safe']).toBe('visible');
  });

  it('redacts recursively through nested structures', () => {
    const out = JSON.stringify(redactValue({ outer: { inner: [{ token: 'leak-me' }] } }));
    expect(out).not.toContain('leak-me');
  });

  it('does not recurse without bound', () => {
    const deep: Record<string, unknown> = {};
    let cursor = deep;
    for (let i = 0; i < 30; i += 1) {
      const next: Record<string, unknown> = {};
      cursor['next'] = next;
      cursor = next;
    }
    expect(() => JSON.stringify(redactValue(deep))).not.toThrow();
    expect(JSON.stringify(redactValue(deep))).toContain('[truncated]');
  });

  it('keeps ordinary values untouched', () => {
    expect(redactValue('plain message')).toBe('plain message');
    expect(redactValue(42)).toBe(42);
    expect(redactValue(null)).toBeNull();
  });
});
