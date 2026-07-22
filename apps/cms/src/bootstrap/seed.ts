import type { Core } from '@strapi/strapi';

/**
 * Idempotent development seed, in German AND English.
 *
 * Guardrails that matter here:
 *
 *  - Keyed on the stable, non-localised `slug`, so running it repeatedly
 *    updates instead of duplicating.
 *  - The two start channels are created exactly as specified, both with
 *    `defaultSubscribed: true`.
 *  - Contact areas are created WITHOUT any person, without an address, phone
 *    number or email. Nothing here is invented: no fictional people, no made-up
 *    phone numbers, no fabricated official statements. Every area is flagged
 *    `isDemoContent: true` so the app can label it visibly, and real contact
 *    details are a documented release gate.
 *  - No news articles are seeded — editorial content is written by the
 *    editorial team, not generated.
 */

interface SeedContext {
  strapi: Core.Strapi;
}

type Localised<T> = { de: T; en: T };

interface ChannelSeed {
  slug: string;
  iconKey: string;
  colorHex: string;
  sortOrder: number;
  defaultSubscribed: boolean;
  name: Localised<string>;
  description: Localised<string>;
}

const CHANNELS: ChannelSeed[] = [
  {
    slug: 'campus-news',
    iconKey: 'campus',
    colorHex: '#5B3FD0',
    sortOrder: 10,
    defaultSubscribed: true,
    name: { de: 'Campus News', en: 'Campus News' },
    description: {
      de: 'Nachrichten rund um den Campus Köthen. Beiträge werden von Studierenden der Studierendenschaft verfasst — als eigener Text oder als eigene Zusammenfassung mit Quellenlink.',
      en: 'News from around the Köthen campus. Articles are written by students of the student body — either as original text or as an original summary with a link to the source.',
    },
  },
  {
    slug: 'fb5-news',
    iconKey: 'computer-science',
    colorHex: '#E8B44F',
    sortOrder: 20,
    defaultSubscribed: true,
    name: { de: 'FB5 News', en: 'FB5 News' },
    description: {
      de: 'Nachrichten aus dem Fachbereich 5. Beiträge werden von Studierenden der Studierendenschaft verfasst — als eigener Text oder als eigene Zusammenfassung mit Quellenlink.',
      en: 'News from Department 5 (FB5). Articles are written by students of the student body — either as original text or as an original summary with a link to the source.',
    },
  },
];

interface AreaSeed {
  slug: string;
  iconKey: string;
  sortOrder: number;
  name: Localised<string>;
  shortDescription: Localised<string>;
}

/**
 * Neutral placeholders only. Names identify a publicly known point of contact;
 * every actual contact detail is left empty until it has been verified and
 * cleared.
 */
const AREAS: AreaSeed[] = [
  {
    slug: 'studierendenrat',
    iconKey: 'students-council',
    sortOrder: 10,
    name: { de: 'Studierendenrat', en: 'Student Council' },
    shortDescription: {
      de: 'Die gewählte Vertretung der Studierendenschaft. DEMO-EINTRAG: Kontaktdaten sind noch nicht freigegeben und daher leer.',
      en: 'The elected representation of the student body. DEMO ENTRY: contact details are not cleared yet and are therefore empty.',
    },
  },
  {
    slug: 'student-service-center',
    iconKey: 'service-center',
    sortOrder: 20,
    name: { de: 'Student Service Center (SSC)', en: 'Student Service Center (SSC)' },
    shortDescription: {
      de: 'Zentrale Anlaufstelle für Studienorganisation. DEMO-EINTRAG: Kontaktdaten sind noch nicht freigegeben und daher leer.',
      en: 'Central point of contact for study organisation. DEMO ENTRY: contact details are not cleared yet and are therefore empty.',
    },
  },
  {
    slug: 'studentenwerk',
    iconKey: 'student-services',
    sortOrder: 30,
    name: { de: 'Studentenwerk', en: 'Studentenwerk (Student Services)' },
    shortDescription: {
      de: 'Zuständig unter anderem für Mensen und Wohnheime. DEMO-EINTRAG: Kontaktdaten sind noch nicht freigegeben und daher leer.',
      en: 'Responsible for canteens and halls of residence, among other things. DEMO ENTRY: contact details are not cleared yet and are therefore empty.',
    },
  },
];

async function upsertLocalised(
  strapi: Core.Strapi,
  uid: 'api::news-channel.news-channel' | 'api::contact-area.contact-area',
  slug: string,
  shared: Record<string, unknown>,
  localised: { de: Record<string, unknown>; en: Record<string, unknown> },
): Promise<'created' | 'updated'> {
  const documents = strapi.documents(uid);

  const existing = await documents.findMany({
    filters: { slug: { $eq: slug } },
    locale: 'de',
    limit: 1,
  });

  const current = Array.isArray(existing) ? existing[0] : undefined;

  if (!current) {
    const created = await documents.create({
      data: { slug, ...shared, ...localised.de } as never,
      locale: 'de',
    });
    await documents.update({
      documentId: (created as { documentId: string }).documentId,
      locale: 'en',
      data: { ...localised.en } as never,
    });
    return 'created';
  }

  const documentId = (current as { documentId: string }).documentId;

  await documents.update({
    documentId,
    locale: 'de',
    data: { ...shared, ...localised.de } as never,
  });
  await documents.update({
    documentId,
    locale: 'en',
    data: { ...localised.en } as never,
  });
  return 'updated';
}

export async function seedDemoContent({ strapi }: SeedContext): Promise<void> {
  let created = 0;
  let updated = 0;

  for (const channel of CHANNELS) {
    const result = await upsertLocalised(
      strapi,
      'api::news-channel.news-channel',
      channel.slug,
      {
        iconKey: channel.iconKey,
        colorHex: channel.colorHex,
        sortOrder: channel.sortOrder,
        isActive: true,
        defaultSubscribed: channel.defaultSubscribed,
      },
      {
        de: { name: channel.name.de, description: channel.description.de },
        en: { name: channel.name.en, description: channel.description.en },
      },
    );
    result === 'created' ? (created += 1) : (updated += 1);
  }

  for (const area of AREAS) {
    const result = await upsertLocalised(
      strapi,
      'api::contact-area.contact-area',
      area.slug,
      {
        iconKey: area.iconKey,
        sortOrder: area.sortOrder,
        isActive: true,
        // Marks unverified placeholder data so the app can label it visibly.
        isDemoContent: true,
        // Deliberately left unset: generalEmail, phone, website,
        // appointmentUrl, address, openingHours. Nothing is invented.
      },
      {
        de: { name: area.name.de, shortDescription: area.shortDescription.de },
        en: { name: area.name.en, shortDescription: area.shortDescription.en },
      },
    );
    result === 'created' ? (created += 1) : (updated += 1);
  }

  strapi.log.info(
    `[seed] demo content ready: ${created} created, ${updated} updated (de + en, idempotent)`,
  );
}
