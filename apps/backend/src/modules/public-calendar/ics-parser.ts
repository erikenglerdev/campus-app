import ICAL from 'ical.js';

/**
 * RFC-5545 parsing + normalisation for public Google calendars.
 *
 * This is NOT a naive line splitter — it delegates the hard RFC-5545 work
 * (content-line folding, escaping, parameters, VTIMEZONE, RRULE/RDATE/EXDATE,
 * RECURRENCE-ID) to Mozilla's `ical.js` (the Thunderbird calendar engine,
 * MPL-2.0, zero runtime dependencies). `ical.js` never touches the network;
 * this module only ever receives the already-downloaded, size-bounded text.
 *
 * On top of ical.js this module:
 *  - expands recurrences ONLY inside the requested window, with hard caps that
 *    stop a "recurrence bomb" from exhausting CPU/memory,
 *  - normalises every occurrence to absolute instants, with correct all-day
 *    (VALUE=DATE, exclusive DTEND) and time-zone (VTIMEZONE / UTC / floating)
 *    semantics,
 *  - drops every privacy-sensitive property (ATTENDEE, ORGANIZER, CONTACT,
 *    ATTACH, conferencing, alarms, X-*) by simply never reading them,
 *  - keeps DESCRIPTION/LOCATION only when the calendar allows it, as plain text.
 */

export type IcsParseErrorKind =
  'invalidCalendar' | 'unsupportedTimeZone' | 'recurrenceLimitExceeded' | 'eventLimitExceeded';

export class IcsParseError extends Error {
  constructor(
    public readonly kind: IcsParseErrorKind,
    message: string,
  ) {
    super(message);
    this.name = 'IcsParseError';
  }
}

export type EventStatus = 'confirmed' | 'tentative' | 'cancelled';

export interface ParsedEvent {
  uid: string;
  /** ISO of the occurrence's RECURRENCE-ID slot, or null for a single event. */
  recurrenceId: string | null;
  sequence: number | null;
  title: string;
  description: string | null;
  location: string | null;
  /** Absolute instant. For all-day events, the UTC midnight of the local date. */
  start: Date;
  /** Absolute instant, EXCLUSIVE for all-day events. */
  end: Date;
  allDay: boolean;
  status: EventStatus;
  sourceUpdatedAt: Date | null;
  /** Stable identity of this occurrence WITHIN one calendar. */
  occurrenceKey: string;
}

export interface ParseOptions {
  windowStart: Date;
  windowEnd: Date;
  fallbackTimeZone: string;
  includeDescription: boolean;
  includeLocation: boolean;
  maxEvents: number;
  maxOccurrences: number;
  maxOccurrencesPerEvent: number;
  maxTextLength: number;
}

/** Removes control characters (keeping tab/newline), trims and truncates. */
function sanitizeText(value: string | null | undefined, maxLength: number): string | null {
  if (value === null || value === undefined) return null;
  const cleaned = Array.from(value)
    .filter((ch) => {
      const c = ch.charCodeAt(0);
      return c === 9 || c === 10 || (c >= 32 && c !== 127);
    })
    .join('');
  const trimmed = cleaned.slice(0, maxLength).trimEnd();
  return trimmed.length > 0 ? trimmed : null;
}

/** Milliseconds to add to a UTC instant to obtain the wall clock in `tz`. */
function tzOffsetMs(instant: Date, tz: string): number {
  const dtf = new Intl.DateTimeFormat('en-US', {
    timeZone: tz,
    hour12: false,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
  const parts = new Map<string, number>();
  for (const part of dtf.formatToParts(instant)) {
    if (part.type !== 'literal') parts.set(part.type, Number(part.value));
  }
  const get = (key: string): number => parts.get(key) ?? 0;
  let hour = get('hour');
  if (hour === 24) hour = 0;
  const asUtc = Date.UTC(
    get('year'),
    get('month') - 1,
    get('day'),
    hour,
    get('minute'),
    get('second'),
  );
  return asUtc - instant.getTime();
}

/** Interprets a wall-clock time in `tz` as an absolute instant (DST-correct). */
function zonedWallClockToUtc(
  y: number,
  month1: number,
  d: number,
  h: number,
  mi: number,
  s: number,
  tz: string,
): Date {
  const guess = Date.UTC(y, month1 - 1, d, h, mi, s);
  const offset = tzOffsetMs(new Date(guess), tz);
  return new Date(guess - offset);
}

interface AbsoluteTime {
  date: Date;
  allDay: boolean;
}

function toAbsolute(time: ICAL.Time, fallbackTimeZone: string): AbsoluteTime {
  if (time.isDate) {
    // VALUE=DATE is a local calendar date, never a UTC instant. Represent it as
    // the UTC midnight of that date so no device/UTC-midnight shift is possible.
    return { date: new Date(Date.UTC(time.year, time.month - 1, time.day)), allDay: true };
  }
  const zoneId: string | undefined = time.zone?.tzid;
  if (zoneId && zoneId !== 'floating') {
    // UTC or a registered VTIMEZONE: ical.js applies the offset for us.
    return { date: time.toJSDate(), allDay: false };
  }
  // Floating date-time: interpret the wall clock in the configured fallback.
  return {
    date: zonedWallClockToUtc(
      time.year,
      time.month,
      time.day,
      time.hour,
      time.minute,
      time.second,
      fallbackTimeZone,
    ),
    allDay: false,
  };
}

function normalizeStatus(raw: unknown): EventStatus {
  const value = typeof raw === 'string' ? raw.toUpperCase() : '';
  if (value === 'CANCELLED') return 'cancelled';
  if (value === 'TENTATIVE') return 'tentative';
  return 'confirmed';
}

function assertTimeZonesResolvable(vevent: ICAL.Component): void {
  for (const name of ['dtstart', 'dtend']) {
    const prop = vevent.getFirstProperty(name);
    if (!prop) continue;
    const tzid = prop.getParameter('tzid');
    if (typeof tzid === 'string' && tzid !== 'UTC' && !ICAL.TimezoneService.has(tzid)) {
      throw new IcsParseError(
        'unsupportedTimeZone',
        'A referenced time zone is not defined by the feed.',
      );
    }
  }
}

export function parseIcs(raw: string, options: ParseOptions): ParsedEvent[] {
  // Validate the fallback zone up front; an invalid one is a config error.
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: options.fallbackTimeZone });
  } catch {
    throw new IcsParseError('unsupportedTimeZone', 'The fallback time zone is invalid.');
  }

  let root: ICAL.Component;
  try {
    // ical.js `parse` is typed as `any`; the jCal result is fed straight into
    // Component, which is the intended, documented usage.
    // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-argument
    const jcal = ICAL.parse(raw);
    // eslint-disable-next-line @typescript-eslint/no-unsafe-argument
    root = new ICAL.Component(jcal);
  } catch {
    throw new IcsParseError('invalidCalendar', 'The body is not a valid iCalendar object.');
  }
  if (root.name !== 'vcalendar') {
    throw new IcsParseError('invalidCalendar', 'The body is not a VCALENDAR.');
  }

  // Register the feed's own VTIMEZONEs in an isolated, per-call registry so one
  // calendar's zones can never bleed into another's.
  ICAL.TimezoneService.reset();
  for (const vtz of root.getAllSubcomponents('vtimezone')) {
    try {
      ICAL.TimezoneService.register(vtz);
    } catch {
      // A malformed VTIMEZONE is ignored; a referencing event is caught below.
    }
  }

  const vevents = root.getAllSubcomponents('vevent');
  if (vevents.length > options.maxEvents) {
    throw new IcsParseError('eventLimitExceeded', 'The feed contains too many events.');
  }

  // Group by UID: the component without a RECURRENCE-ID is the master; the rest
  // are overrides of individual occurrences.
  const masters = new Map<string, ICAL.Component>();
  const overrides = new Map<string, ICAL.Component[]>();
  const orphanOverrides: ICAL.Component[] = [];

  for (const vevent of vevents) {
    const uid = vevent.getFirstPropertyValue('uid');
    if (typeof uid !== 'string' || uid.length === 0) continue;
    assertTimeZonesResolvable(vevent);
    if (vevent.getFirstProperty('recurrence-id')) {
      const list = overrides.get(uid) ?? [];
      list.push(vevent);
      overrides.set(uid, list);
    } else {
      masters.set(uid, vevent);
    }
  }
  for (const [uid, list] of overrides) {
    if (!masters.has(uid)) orphanOverrides.push(...list);
  }

  const windowStart = options.windowStart.getTime();
  const windowEnd = options.windowEnd.getTime();
  const result: ParsedEvent[] = [];

  const emit = (
    event: ICAL.Event,
    startTime: ICAL.Time,
    endTime: ICAL.Time,
    recurrenceId: ICAL.Time | null,
  ): void => {
    const abs = toAbsolute(startTime, options.fallbackTimeZone);
    const absEnd = toAbsolute(endTime, options.fallbackTimeZone);
    if (absEnd.date.getTime() <= windowStart || abs.date.getTime() >= windowEnd) return;

    const comp = event.component;
    const uid = String(event.uid);
    const recurrenceIso = recurrenceId
      ? toAbsolute(recurrenceId, options.fallbackTimeZone).date.toISOString()
      : null;
    const sequenceRaw = comp.getFirstPropertyValue('sequence');
    const lastModified = comp.getFirstPropertyValue('last-modified');

    result.push({
      uid,
      recurrenceId: recurrenceIso,
      sequence: typeof sequenceRaw === 'number' ? sequenceRaw : null,
      title: sanitizeText(stringOrNull(event.summary), options.maxTextLength) ?? '',
      description: options.includeDescription
        ? sanitizeText(stringOrNull(event.description), options.maxTextLength)
        : null,
      location: options.includeLocation
        ? sanitizeText(stringOrNull(event.location), options.maxTextLength)
        : null,
      start: abs.date,
      end: absEnd.date,
      allDay: abs.allDay,
      status: normalizeStatus(comp.getFirstPropertyValue('status')),
      sourceUpdatedAt: lastModified instanceof ICAL.Time ? lastModified.toJSDate() : null,
      occurrenceKey: recurrenceIso ? `${uid}::${recurrenceIso}` : uid,
    });

    if (result.length > options.maxOccurrences) {
      throw new IcsParseError('recurrenceLimitExceeded', 'Too many expanded occurrences in total.');
    }
  };

  for (const [uid, masterComp] of masters) {
    const event = new ICAL.Event(masterComp);
    for (const override of overrides.get(uid) ?? []) {
      event.relateException(override);
    }

    if (!event.isRecurring()) {
      emit(event, event.startDate, event.endDate, null);
      continue;
    }

    const iterator = event.iterator();
    let steps = 0;
    let next: ICAL.Time | null;
    while ((next = iterator.next())) {
      steps += 1;
      if (steps > options.maxOccurrencesPerEvent) {
        throw new IcsParseError(
          'recurrenceLimitExceeded',
          'A recurrence rule expanded past the per-event limit.',
        );
      }
      const details = event.getOccurrenceDetails(next);
      const occStart = toAbsolute(details.startDate, options.fallbackTimeZone).date.getTime();
      if (occStart >= windowEnd) break; // iteration is monotonic
      // `details.item` is the override for this slot when one exists (moved or
      // cancelled), otherwise the master — so title/status reflect the override.
      emit(details.item, details.startDate, details.endDate, details.recurrenceId);
    }
  }

  // Overrides whose master is not in the feed: emit them as standalone events.
  for (const override of orphanOverrides) {
    const event = new ICAL.Event(override);
    emit(event, event.startDate, event.endDate, event.recurrenceId ?? null);
  }

  return result;
}

function stringOrNull(value: unknown): string | null {
  return typeof value === 'string' ? value : null;
}
