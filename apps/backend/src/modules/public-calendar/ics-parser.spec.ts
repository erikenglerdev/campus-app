import { IcsParseError, ParseOptions, ParsedEvent, parseIcs } from './ics-parser';

function first(events: ParsedEvent[]): ParsedEvent {
  const e = events[0];
  if (!e) throw new Error('expected at least one event');
  return e;
}

/**
 * Synthetic ICS fixtures only. Every calendar below is made up ("Beispielkurs",
 * "Mustertermine", "Öffentliche Veranstaltungen") — no real Google calendar,
 * no real people, no real e-mail addresses.
 *
 * ICS uses CRLF line endings; the fixtures use \r\n deliberately.
 */
function ics(lines: string[]): string {
  return lines.join('\r\n') + '\r\n';
}

const VCAL_OPEN = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Synthetic//Test//EN'];
const VCAL_CLOSE = ['END:VCALENDAR'];

function baseOptions(overrides: Partial<ParseOptions> = {}): ParseOptions {
  return {
    windowStart: new Date('2026-01-01T00:00:00.000Z'),
    windowEnd: new Date('2026-12-31T00:00:00.000Z'),
    fallbackTimeZone: 'Europe/Berlin',
    includeDescription: true,
    includeLocation: true,
    maxEvents: 1000,
    maxOccurrences: 5000,
    maxOccurrencesPerEvent: 750,
    maxTextLength: 2000,
    ...overrides,
  };
}

describe('parseIcs — invalid input', () => {
  it('rejects a non-VCALENDAR body', () => {
    expect(() => parseIcs('this is not ics', baseOptions())).toThrow(IcsParseError);
  });
  it('rejects an empty string', () => {
    expect(() => parseIcs('', baseOptions())).toThrow(IcsParseError);
  });
  it('accepts a valid but empty VCALENDAR as zero events', () => {
    const events = parseIcs(ics([...VCAL_OPEN, ...VCAL_CLOSE]), baseOptions());
    expect(events).toEqual([]);
  });
});

describe('parseIcs — single timed events', () => {
  it('parses a UTC timed event to an absolute instant', () => {
    const events = parseIcs(
      ics([
        ...VCAL_OPEN,
        'BEGIN:VEVENT',
        'UID:evt-utc-1',
        'DTSTAMP:20260301T120000Z',
        'DTSTART:20260610T080000Z',
        'DTEND:20260610T093000Z',
        'SUMMARY:Beispielsitzung',
        'END:VEVENT',
        ...VCAL_CLOSE,
      ]),
      baseOptions(),
    );
    expect(events).toHaveLength(1);
    expect(first(events).title).toBe('Beispielsitzung');
    expect(first(events).allDay).toBe(false);
    expect(first(events).start.toISOString()).toBe('2026-06-10T08:00:00.000Z');
    expect(first(events).end.toISOString()).toBe('2026-06-10T09:30:00.000Z');
  });

  it('converts a TZID + VTIMEZONE event to the correct UTC instant (summer, +02:00)', () => {
    const events = parseIcs(
      ics([
        ...VCAL_OPEN,
        'BEGIN:VTIMEZONE',
        'TZID:Europe/Berlin',
        'BEGIN:DAYLIGHT',
        'TZOFFSETFROM:+0100',
        'TZOFFSETTO:+0200',
        'TZNAME:CEST',
        'DTSTART:19700329T020000',
        'RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU',
        'END:DAYLIGHT',
        'BEGIN:STANDARD',
        'TZOFFSETFROM:+0200',
        'TZOFFSETTO:+0100',
        'TZNAME:CET',
        'DTSTART:19701025T030000',
        'RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU',
        'END:STANDARD',
        'END:VTIMEZONE',
        'BEGIN:VEVENT',
        'UID:evt-tz-1',
        'DTSTAMP:20260301T120000Z',
        'DTSTART;TZID=Europe/Berlin:20260610T100000',
        'DTEND;TZID=Europe/Berlin:20260610T113000',
        'SUMMARY:Mustertermin',
        'END:VEVENT',
        ...VCAL_CLOSE,
      ]),
      baseOptions(),
    );
    expect(events).toHaveLength(1);
    // 10:00 CEST (+02:00) == 08:00 UTC
    expect(first(events).start.toISOString()).toBe('2026-06-10T08:00:00.000Z');
    expect(first(events).end.toISOString()).toBe('2026-06-10T09:30:00.000Z');
  });

  it('derives the end from DTSTART + DURATION', () => {
    const events = parseIcs(
      ics([
        ...VCAL_OPEN,
        'BEGIN:VEVENT',
        'UID:evt-dur-1',
        'DTSTAMP:20260301T120000Z',
        'DTSTART:20260610T080000Z',
        'DURATION:PT1H30M',
        'SUMMARY:Mit Dauer',
        'END:VEVENT',
        ...VCAL_CLOSE,
      ]),
      baseOptions(),
    );
    expect(first(events).end.toISOString()).toBe('2026-06-10T09:30:00.000Z');
  });
});

describe('parseIcs — all-day events', () => {
  it('treats VALUE=DATE as a local calendar day with an EXCLUSIVE end date', () => {
    const events = parseIcs(
      ics([
        ...VCAL_OPEN,
        'BEGIN:VEVENT',
        'UID:evt-allday-1',
        'DTSTAMP:20260301T120000Z',
        'DTSTART;VALUE=DATE:20260610',
        'DTEND;VALUE=DATE:20260611',
        'SUMMARY:Ganztag',
        'END:VEVENT',
        ...VCAL_CLOSE,
      ]),
      baseOptions(),
    );
    expect(events).toHaveLength(1);
    expect(first(events).allDay).toBe(true);
    // Start is the local date at 00:00; end is the exclusive next day at 00:00.
    // Represented as the UTC midnight of those dates (no device-zone shift).
    expect(first(events).start.toISOString()).toBe('2026-06-10T00:00:00.000Z');
    expect(first(events).end.toISOString()).toBe('2026-06-11T00:00:00.000Z');
  });
});

describe('parseIcs — recurrence', () => {
  it('expands a weekly RRULE only within the window', () => {
    const events = parseIcs(
      ics([
        ...VCAL_OPEN,
        'BEGIN:VEVENT',
        'UID:evt-rrule-1',
        'DTSTAMP:20260301T120000Z',
        'DTSTART:20260601T080000Z',
        'DTEND:20260601T090000Z',
        'RRULE:FREQ=WEEKLY;COUNT=5',
        'SUMMARY:Wöchentlich',
        'END:VEVENT',
        ...VCAL_CLOSE,
      ]),
      baseOptions({
        windowStart: new Date('2026-06-01T00:00:00.000Z'),
        windowEnd: new Date('2026-06-15T00:00:00.000Z'),
      }),
    );
    // Jun 1, Jun 8 within window; Jun 15 is the exclusive end boundary; later ones out.
    const starts = events.map((e) => e.start.toISOString());
    expect(starts).toContain('2026-06-01T08:00:00.000Z');
    expect(starts).toContain('2026-06-08T08:00:00.000Z');
    expect(starts.every((s) => new Date(s) < new Date('2026-06-15T00:00:00.000Z'))).toBe(true);
    // Every occurrence keeps the master UID and gets a distinct occurrence key.
    expect(new Set(events.map((e) => e.uid))).toEqual(new Set(['evt-rrule-1']));
    expect(new Set(events.map((e) => e.occurrenceKey)).size).toBe(events.length);
  });

  it('applies EXDATE to remove one occurrence', () => {
    const events = parseIcs(
      ics([
        ...VCAL_OPEN,
        'BEGIN:VEVENT',
        'UID:evt-exdate-1',
        'DTSTAMP:20260301T120000Z',
        'DTSTART:20260601T080000Z',
        'DTEND:20260601T090000Z',
        'RRULE:FREQ=WEEKLY;COUNT=3',
        'EXDATE:20260608T080000Z',
        'SUMMARY:Mit Ausnahme',
        'END:VEVENT',
        ...VCAL_CLOSE,
      ]),
      baseOptions({
        windowStart: new Date('2026-06-01T00:00:00.000Z'),
        windowEnd: new Date('2026-06-30T00:00:00.000Z'),
      }),
    );
    const starts = events.map((e) => e.start.toISOString());
    expect(starts).toContain('2026-06-01T08:00:00.000Z');
    expect(starts).not.toContain('2026-06-08T08:00:00.000Z');
    expect(starts).toContain('2026-06-15T08:00:00.000Z');
  });

  it('applies a RECURRENCE-ID override that moves one occurrence', () => {
    const events = parseIcs(
      ics([
        ...VCAL_OPEN,
        'BEGIN:VEVENT',
        'UID:evt-override-1',
        'DTSTAMP:20260301T120000Z',
        'DTSTART:20260601T080000Z',
        'DTEND:20260601T090000Z',
        'RRULE:FREQ=WEEKLY;COUNT=3',
        'SUMMARY:Serie',
        'END:VEVENT',
        'BEGIN:VEVENT',
        'UID:evt-override-1',
        'RECURRENCE-ID:20260608T080000Z',
        'DTSTAMP:20260301T120000Z',
        'DTSTART:20260608T140000Z',
        'DTEND:20260608T150000Z',
        'SUMMARY:Verschoben',
        'END:VEVENT',
        ...VCAL_CLOSE,
      ]),
      baseOptions({
        windowStart: new Date('2026-06-01T00:00:00.000Z'),
        windowEnd: new Date('2026-06-30T00:00:00.000Z'),
      }),
    );
    const moved = events.find((e) => e.title === 'Verschoben');
    expect(moved).toBeDefined();
    expect(moved?.start.toISOString()).toBe('2026-06-08T14:00:00.000Z');
    // The original 08:00 occurrence on Jun 8 must be gone.
    expect(events.filter((e) => e.start.toISOString() === '2026-06-08T08:00:00.000Z')).toHaveLength(
      0,
    );
  });

  it('marks a cancelled whole event', () => {
    const events = parseIcs(
      ics([
        ...VCAL_OPEN,
        'BEGIN:VEVENT',
        'UID:evt-cancelled-1',
        'DTSTAMP:20260301T120000Z',
        'DTSTART:20260610T080000Z',
        'DTEND:20260610T090000Z',
        'STATUS:CANCELLED',
        'SUMMARY:Abgesagt',
        'END:VEVENT',
        ...VCAL_CLOSE,
      ]),
      baseOptions(),
    );
    expect(events).toHaveLength(1);
    expect(first(events).status).toBe('cancelled');
  });
});

describe('parseIcs — redaction and safety', () => {
  it('never carries ATTENDEE / ORGANIZER e-mail addresses', () => {
    const events = parseIcs(
      ics([
        ...VCAL_OPEN,
        'BEGIN:VEVENT',
        'UID:evt-pii-1',
        'DTSTAMP:20260301T120000Z',
        'DTSTART:20260610T080000Z',
        'DTEND:20260610T090000Z',
        'SUMMARY:Öffentliche Veranstaltung',
        'ORGANIZER;CN=Muster:mailto:organizer@example.invalid',
        'ATTENDEE;CN=Gast:mailto:attendee@example.invalid',
        'DESCRIPTION:Beschreibung ohne PII',
        'END:VEVENT',
        ...VCAL_CLOSE,
      ]),
      baseOptions(),
    );
    const serialised = JSON.stringify(first(events));
    expect(serialised).not.toContain('example.invalid');
    expect(serialised).not.toContain('organizer');
    expect(serialised).not.toContain('attendee');
  });

  it('omits description and location when the calendar disables them', () => {
    const events = parseIcs(
      ics([
        ...VCAL_OPEN,
        'BEGIN:VEVENT',
        'UID:evt-gate-1',
        'DTSTAMP:20260301T120000Z',
        'DTSTART:20260610T080000Z',
        'DTEND:20260610T090000Z',
        'SUMMARY:Ohne Details',
        'DESCRIPTION:Geheime Beschreibung',
        'LOCATION:Geheimer Ort',
        'END:VEVENT',
        ...VCAL_CLOSE,
      ]),
      baseOptions({ includeDescription: false, includeLocation: false }),
    );
    expect(first(events).description).toBeNull();
    expect(first(events).location).toBeNull();
  });

  it('unescapes text and strips control characters, and never renders HTML', () => {
    const events = parseIcs(
      ics([
        ...VCAL_OPEN,
        'BEGIN:VEVENT',
        'UID:evt-escape-1',
        'DTSTAMP:20260301T120000Z',
        'DTSTART:20260610T080000Z',
        'DTEND:20260610T090000Z',
        'SUMMARY:Titel mit Komma\\, Semikolon\\; und Zeile\\nZwei',
        'DESCRIPTION:<script>alert(1)</script>',
        'END:VEVENT',
        ...VCAL_CLOSE,
      ]),
      baseOptions(),
    );
    expect(first(events).title).toContain(',');
    expect(first(events).title).toContain(';');
    expect(first(events).title).toContain('\n');
    // Description is kept verbatim as PLAIN TEXT (never parsed as HTML by us).
    expect(first(events).description).toBe('<script>alert(1)</script>');
  });

  it('truncates over-long text', () => {
    const events = parseIcs(
      ics([
        ...VCAL_OPEN,
        'BEGIN:VEVENT',
        'UID:evt-long-1',
        'DTSTAMP:20260301T120000Z',
        'DTSTART:20260610T080000Z',
        'DTEND:20260610T090000Z',
        'SUMMARY:' + 'x'.repeat(500),
        'END:VEVENT',
        ...VCAL_CLOSE,
      ]),
      baseOptions({ maxTextLength: 100 }),
    );
    expect(first(events).title.length).toBeLessThanOrEqual(100);
  });
});

describe('parseIcs — resource limits', () => {
  it('throws when the event count exceeds the limit', () => {
    const many: string[] = [];
    for (let i = 0; i < 5; i++) {
      many.push(
        'BEGIN:VEVENT',
        `UID:evt-${i}`,
        'DTSTAMP:20260301T120000Z',
        'DTSTART:20260610T080000Z',
        'DTEND:20260610T090000Z',
        `SUMMARY:Termin ${i}`,
        'END:VEVENT',
      );
    }
    expect(() =>
      parseIcs(ics([...VCAL_OPEN, ...many, ...VCAL_CLOSE]), baseOptions({ maxEvents: 3 })),
    ).toThrow(IcsParseError);
  });

  it('throws recurrenceLimitExceeded on an unbounded high-frequency rule', () => {
    expect(() =>
      parseIcs(
        ics([
          ...VCAL_OPEN,
          'BEGIN:VEVENT',
          'UID:evt-bomb-1',
          'DTSTAMP:20260301T120000Z',
          'DTSTART:20260101T000000Z',
          'DTEND:20260101T000100Z',
          'RRULE:FREQ=MINUTELY',
          'SUMMARY:Bombe',
          'END:VEVENT',
          ...VCAL_CLOSE,
        ]),
        baseOptions({ maxOccurrencesPerEvent: 100 }),
      ),
    ).toThrow(IcsParseError);
  });
});
