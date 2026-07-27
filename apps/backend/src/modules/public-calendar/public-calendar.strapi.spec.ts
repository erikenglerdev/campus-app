import { validateCatalog } from './public-calendar.strapi';

/** Synthetic entries only — a made-up calendar id inside a valid share link. */
const CID = Buffer.from('beispielkalender-a@group.calendar.google.com', 'utf8').toString(
  'base64url',
);
const SHARE = `https://calendar.google.com/calendar/u/0?cid=${CID}`;

function deEntry(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    slug: 'beispielkalender-a',
    name: 'Beispielkalender A',
    description: 'Öffentliche Veranstaltungen',
    googleShareUrl: SHARE,
    colorHex: '#5B3FD0',
    iconKey: 'calendar',
    sortOrder: 1,
    isActive: true,
    defaultSubscribed: true,
    attribution: 'Quelle: Beispiel',
    showDescription: true,
    showLocation: false,
    timeZone: 'Europe/Berlin',
    ...overrides,
  };
}

describe('validateCatalog', () => {
  it('accepts a valid entry and overlays the English translation by slug', () => {
    const result = validateCatalog(
      [deEntry()],
      [{ ...deEntry(), name: 'Sample calendar A', description: 'Public events' }],
    );
    expect(result.definitions).toHaveLength(1);
    const def = result.definitions[0];
    expect(def?.slug).toBe('beispielkalender-a');
    expect(def?.googleCalendarId).toBe('beispielkalender-a@group.calendar.google.com');
    expect(def?.nameDe).toBe('Beispielkalender A');
    expect(def?.nameEn).toBe('Sample calendar A');
    expect(def?.colorHex).toBe('#5B3FD0');
    expect(def?.defaultSubscribed).toBe(true);
  });

  it('rejects an entry with an invalid share URL but keeps the others', () => {
    const result = validateCatalog(
      [
        deEntry(),
        deEntry({
          slug: 'boese',
          googleShareUrl: 'https://evil.example.com/calendar/render?cid=' + CID,
        }),
        deEntry({
          slug: 'privat',
          googleShareUrl: 'https://calendar.google.com/calendar/ical/x/private-abc/basic.ics',
        }),
      ],
      [],
    );
    expect(result.received).toBe(3);
    expect(result.rejected).toBe(2);
    expect(result.definitions.map((d) => d.slug)).toEqual(['beispielkalender-a']);
  });

  it('rejects a bad slug and a bad colour', () => {
    const result = validateCatalog(
      [deEntry({ slug: 'Bad Slug' }), deEntry({ slug: 'x', colorHex: 'red' })],
      [],
    );
    expect(result.definitions).toHaveLength(0);
    expect(result.rejected).toBe(2);
  });

  it('falls back to Europe/Berlin for an invalid timezone', () => {
    const result = validateCatalog([deEntry({ timeZone: 'Nonsense/Zone' })], []);
    expect(result.definitions[0]?.fallbackTimeZone).toBe('Europe/Berlin');
  });
});
