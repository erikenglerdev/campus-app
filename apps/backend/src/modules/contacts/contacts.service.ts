import { Injectable } from '@nestjs/common';
import { sanitizeBlocks } from '../../common/content/content-blocks';
import { ApiError } from '../../common/errors/api-error';
import { LocaleResolution } from '../../common/locale/locale';
import { StrapiClient, StrapiListResponse, StrapiRequestError } from '../strapi/strapi.client';
import { ContactAreaDetailDto, ContactAreaListItemDto, ContactPersonDto } from './contacts.types';

/**
 * Read model for /v1/contact-areas*.
 *
 * Same locale strategy as news: German is the canonical set, the requested
 * locale is overlaid, and anything untranslated keeps its German text and sets
 * `translationFallback`.
 *
 * A contact area is valid and fully usable WITHOUT any person — several real
 * points of contact are institutional rather than personal.
 */

const CANONICAL_LOCALE = 'de';

type Raw = Record<string, unknown>;

function isRecord(value: unknown): value is Raw {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function str(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0 ? value : null;
}

function httpsUrl(value: unknown): string | null {
  if (typeof value !== 'string' || value.length === 0) {
    return null;
  }
  try {
    return new URL(value).protocol === 'https:' ? value : null;
  } catch {
    return null;
  }
}

/** A syntactically implausible address is dropped rather than shown as a dead link. */
function email(value: unknown): string | null {
  const candidate = str(value);
  if (!candidate) {
    return null;
  }
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(candidate) ? candidate : null;
}

function mapPerson(raw: unknown): ContactPersonDto | null {
  if (!isRecord(raw) || raw['isActive'] === false) {
    return null;
  }
  const name = str(raw['name']);
  if (!name) {
    return null;
  }
  const image = isRecord(raw['profileImage']) ? httpsUrl(raw['profileImage']['url']) : null;
  return {
    name,
    role: str(raw['role']),
    description: str(raw['description']),
    email: email(raw['email']),
    phone: str(raw['phone']),
    website: httpsUrl(raw['website']),
    profileImage: image,
    sortOrder: typeof raw['sortOrder'] === 'number' ? raw['sortOrder'] : 0,
  };
}

function mapAreaBase(raw: Raw): Omit<ContactAreaListItemDto, 'personCount'> {
  return {
    slug: String(raw['slug'] ?? ''),
    name: String(raw['name'] ?? ''),
    shortDescription: String(raw['shortDescription'] ?? ''),
    iconKey: String(raw['iconKey'] ?? 'contact'),
    sortOrder: typeof raw['sortOrder'] === 'number' ? raw['sortOrder'] : 0,
    generalEmail: email(raw['generalEmail']),
    phone: str(raw['phone']),
    website: httpsUrl(raw['website']),
    appointmentUrl: httpsUrl(raw['appointmentUrl']),
    address: str(raw['address']),
    openingHours: str(raw['openingHours']),
    isDemoContent: raw['isDemoContent'] === true,
  };
}

function activePersons(raw: Raw): ContactPersonDto[] {
  const persons = Array.isArray(raw['persons']) ? raw['persons'] : [];
  return persons
    .map(mapPerson)
    .filter((person): person is ContactPersonDto => person !== null)
    .sort((a, b) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name));
}

/** Fields shared across locales; the overlay must not overwrite them. */
function sharedFields(canonical: Raw): Raw {
  return {
    slug: canonical['slug'],
    iconKey: canonical['iconKey'],
    sortOrder: canonical['sortOrder'],
    isActive: canonical['isActive'],
    isDemoContent: canonical['isDemoContent'],
    generalEmail: canonical['generalEmail'],
    phone: canonical['phone'],
    website: canonical['website'],
    appointmentUrl: canonical['appointmentUrl'],
  };
}

@Injectable()
export class ContactsService {
  constructor(private readonly strapi: StrapiClient) {}

  private async fetch(query: Record<string, unknown>): Promise<Raw[]> {
    try {
      const response = await this.strapi.get<StrapiListResponse<Raw>>('/api/contact-areas', query);
      return Array.isArray(response?.data) ? response.data : [];
    } catch (error) {
      if (error instanceof StrapiRequestError) {
        throw new ApiError(
          error.kind === 'timeout' ? 'UPSTREAM_TIMEOUT' : 'UPSTREAM_UNAVAILABLE',
        );
      }
      throw error;
    }
  }

  private static bySlug(entries: Raw[]): Map<string, Raw> {
    const map = new Map<string, Raw>();
    for (const entry of entries) {
      const slug = entry['slug'];
      if (typeof slug === 'string' && slug && !map.has(slug)) {
        map.set(slug, entry);
      }
    }
    return map;
  }

  async listAreas(locale: LocaleResolution): Promise<{
    data: ContactAreaListItemDto[];
    translationFallback: boolean;
  }> {
    const baseQuery = {
      filters: { isActive: { $eq: true } },
      sort: ['sortOrder:asc', 'name:asc'],
      pagination: { pageSize: 100 },
      // Persons are populated only to count the active ones; no personal data
      // beyond that reaches the list response.
      populate: { persons: { fields: ['name', 'isActive'] } },
    };

    const canonical = await this.fetch({ ...baseQuery, locale: CANONICAL_LOCALE });

    let translated = new Map<string, Raw>();
    if (locale.resolvedLocale !== CANONICAL_LOCALE) {
      translated = ContactsService.bySlug(
        await this.fetch({ ...baseQuery, locale: locale.resolvedLocale }),
      );
    }

    let fallbackUsed = false;
    const data = canonical.map((raw) => {
      const slug = String(raw['slug'] ?? '');
      const localised = translated.get(slug);
      if (locale.resolvedLocale !== CANONICAL_LOCALE && !localised) {
        fallbackUsed = true;
      }
      const merged = localised ? { ...raw, ...localised, ...sharedFields(raw) } : raw;
      return { ...mapAreaBase(merged), personCount: activePersons(raw).length };
    });

    data.sort((a, b) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name));

    return { data, translationFallback: fallbackUsed };
  }

  async getArea(
    locale: LocaleResolution,
    slug: string,
  ): Promise<{
    data: ContactAreaDetailDto;
    translationFallback: boolean;
    droppedBlockTypes: string[];
  }> {
    const populate = {
      persons: {
        fields: [
          'name',
          'role',
          'description',
          'email',
          'phone',
          'website',
          'sortOrder',
          'isActive',
        ],
        populate: { profileImage: { fields: ['url'] } },
      },
    };

    const canonical = (
      await this.fetch({
        filters: { slug: { $eq: slug }, isActive: { $eq: true } },
        populate,
        pagination: { pageSize: 1 },
        locale: CANONICAL_LOCALE,
      })
    )[0];

    if (!canonical) {
      throw new ApiError('CONTACT_AREA_NOT_FOUND', locale.resolvedLocale);
    }

    let localised: Raw | undefined;
    if (locale.resolvedLocale !== CANONICAL_LOCALE) {
      localised = (
        await this.fetch({
          filters: { slug: { $eq: slug }, isActive: { $eq: true } },
          populate,
          pagination: { pageSize: 1 },
          locale: locale.resolvedLocale,
        })
      )[0];
    }

    const merged = localised
      ? { ...canonical, ...localised, ...sharedFields(canonical) }
      : canonical;

    const { blocks, droppedBlockTypes } = sanitizeBlocks(merged['description']);

    return {
      data: {
        ...mapAreaBase(merged),
        description: blocks,
        // Persons carry only non-localised contact data plus localised role and
        // description; the localised variant wins when present.
        persons: activePersons(localised ?? canonical),
      },
      translationFallback: locale.resolvedLocale !== CANONICAL_LOCALE && !localised,
      droppedBlockTypes,
    };
  }
}
