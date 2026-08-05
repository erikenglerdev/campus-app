import { Injectable } from '@nestjs/common';
import { ApiError } from '../../common/errors/api-error';
import { LocaleResolution } from '../../common/locale/locale';
import { StrapiClient, StrapiListResponse, StrapiRequestError } from '../strapi/strapi.client';
import { mapChannel, mapNewsDetail, mapNewsListItem } from './news.mapper';
import { NewsChannelDto, NewsDetailDto, NewsListItemDto } from './news.types';
import { asString } from '../../common/util/coerce';

/**
 * Read model for /v1/news*.
 *
 * ## Locale strategy
 *
 * Strapi i18n omits a document entirely when the requested locale has no
 * translation. Serving the requested locale alone would therefore make an
 * untranslated article silently disappear.
 *
 * Instead German is always fetched as the CANONICAL set — it decides which
 * articles exist, their order and the pagination — and the requested locale is
 * overlaid on top. Anything with no translation keeps its German text and the
 * response is flagged with `translationFallback: true`.
 *
 * Nothing is ever machine-translated.
 */

const CANONICAL_LOCALE = 'de';

type Raw = Record<string, unknown>;

export interface NewsQuery {
  channels: string[];
  /**
   * Distinguishes "?channels=" (present but empty -> deliberately no channels)
   * from an absent parameter (-> all active channels). See docs/api.md §5.
   */
  channelsParamPresent: boolean;
  page: number;
  pageSize: number;
}

export interface PaginationResult {
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}

@Injectable()
export class NewsService {
  constructor(private readonly strapi: StrapiClient) {}

  private async fetch(path: string, query: Record<string, unknown>): Promise<Raw[]> {
    try {
      const response = await this.strapi.get<StrapiListResponse<Raw>>(path, query);
      return Array.isArray(response?.data) ? response.data : [];
    } catch (error) {
      throw NewsService.toApiError(error);
    }
  }

  private async fetchWithMeta(
    path: string,
    query: Record<string, unknown>,
  ): Promise<StrapiListResponse<Raw>> {
    try {
      const response = await this.strapi.get<StrapiListResponse<Raw>>(path, query);
      return { data: Array.isArray(response?.data) ? response.data : [], meta: response?.meta };
    } catch (error) {
      throw NewsService.toApiError(error);
    }
  }

  private static toApiError(error: unknown): ApiError {
    if (error instanceof StrapiRequestError) {
      return new ApiError(error.kind === 'timeout' ? 'UPSTREAM_TIMEOUT' : 'UPSTREAM_UNAVAILABLE');
    }
    if (error instanceof ApiError) {
      return error;
    }
    return new ApiError('UPSTREAM_UNAVAILABLE');
  }

  /** Indexes documents by their stable, non-localised slug. */
  private static bySlug(entries: Raw[]): Map<string, Raw> {
    const map = new Map<string, Raw>();
    for (const entry of entries) {
      const slug = entry['slug'];
      if (typeof slug === 'string' && slug.length > 0 && !map.has(slug)) {
        map.set(slug, entry);
      }
    }
    return map;
  }

  async getChannels(locale: LocaleResolution): Promise<{
    data: NewsChannelDto[];
    translationFallback: boolean;
  }> {
    const baseQuery = {
      filters: { isActive: { $eq: true } },
      sort: ['sortOrder:asc', 'name:asc'],
      pagination: { pageSize: 100 },
    };

    const canonical = await this.fetch('/api/news-channels', {
      ...baseQuery,
      locale: CANONICAL_LOCALE,
    });

    let translated = new Map<string, Raw>();
    if (locale.resolvedLocale !== CANONICAL_LOCALE) {
      translated = NewsService.bySlug(
        await this.fetch('/api/news-channels', { ...baseQuery, locale: locale.resolvedLocale }),
      );
    }

    let fallbackUsed = false;
    const data = canonical.map((raw) => {
      const slug = asString(raw['slug']);
      const localised = translated.get(slug);
      if (locale.resolvedLocale !== CANONICAL_LOCALE && !localised) {
        fallbackUsed = true;
      }
      return mapChannel(localised ?? raw);
    });

    // Sort locally as well: the upstream sort is by the canonical name, and the
    // translated name may order differently.
    data.sort((a, b) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name));

    return { data, translationFallback: fallbackUsed };
  }

  async getNews(
    locale: LocaleResolution,
    query: NewsQuery,
  ): Promise<{
    data: NewsListItemDto[];
    pagination: PaginationResult;
    translationFallback: boolean;
    droppedBlockTypes: string[];
  }> {
    // "?channels=" means the user deliberately deselected everything. Answer
    // with an empty list and do not bother the CMS at all.
    if (query.channelsParamPresent && query.channels.length === 0) {
      return {
        data: [],
        pagination: { page: query.page, pageSize: query.pageSize, total: 0, totalPages: 0 },
        translationFallback: false,
        droppedBlockTypes: [],
      };
    }

    const now = new Date().toISOString();
    const filters: Record<string, unknown> = {
      // Only currently valid articles. A null bound means "unbounded".
      $and: [
        { $or: [{ validFrom: { $null: true } }, { validFrom: { $lte: now } }] },
        { $or: [{ validUntil: { $null: true } }, { validUntil: { $gte: now } }] },
      ],
    };

    if (query.channels.length > 0) {
      filters['channels'] = { slug: { $in: query.channels } };
    } else {
      // No explicit selection: still restrict to articles in an ACTIVE channel.
      filters['channels'] = { isActive: { $eq: true } };
    }

    const baseQuery = {
      filters,
      sort: ['isPinned:desc', 'publishedAt:desc', 'slug:asc'],
      populate: {
        channels: { fields: ['slug', 'name', 'colorHex'] },
        authors: { fields: ['name', 'role'] },
        heroImage: { fields: ['url', 'alternativeText', 'width', 'height'] },
      },
      pagination: { page: query.page, pageSize: query.pageSize },
    };

    const canonical = await this.fetchWithMeta('/api/news-articles', {
      ...baseQuery,
      locale: CANONICAL_LOCALE,
    });

    // An article present in several requested channels must appear once.
    const unique = [...NewsService.bySlug(canonical.data).values()];

    let translated = new Map<string, Raw>();
    if (locale.resolvedLocale !== CANONICAL_LOCALE && unique.length > 0) {
      translated = NewsService.bySlug(
        await this.fetch('/api/news-articles', {
          filters: { slug: { $in: unique.map((entry) => asString(entry['slug'])) } },
          populate: baseQuery.populate,
          pagination: { pageSize: unique.length },
          locale: locale.resolvedLocale,
        }),
      );
    }

    let fallbackUsed = false;
    // Collected across the whole page: a block type the CMS added is a fact
    // about the response, not about one article, and reporting it once keeps
    // the meta readable.
    const dropped = new Set<string>();
    const data = unique.map((raw) => {
      const slug = asString(raw['slug']);
      const localised = translated.get(slug);
      if (locale.resolvedLocale !== CANONICAL_LOCALE && !localised) {
        fallbackUsed = true;
      }
      // Relations and media are not localised — always take them from canonical.
      const mapped = mapNewsListItem(
        localised ? { ...raw, ...localised, ...NewsService.sharedFields(raw) } : raw,
      );
      for (const type of mapped.droppedBlockTypes) {
        dropped.add(type);
      }
      return mapped.item;
    });

    // Deterministic order, independent of what the CMS returned.
    data.sort(
      (a, b) =>
        Number(b.isPinned) - Number(a.isPinned) ||
        (b.publishedAt ?? '').localeCompare(a.publishedAt ?? '') ||
        a.slug.localeCompare(b.slug),
    );

    const upstream = canonical.meta?.pagination;
    const total = upstream?.total ?? data.length;
    const pageSize = upstream?.pageSize ?? query.pageSize;

    return {
      data,
      pagination: {
        page: upstream?.page ?? query.page,
        pageSize,
        total,
        totalPages: upstream?.pageCount ?? Math.ceil(total / Math.max(pageSize, 1)),
      },
      translationFallback: fallbackUsed,
      // Sorted so the response is byte-stable for the same input.
      droppedBlockTypes: [...dropped].sort(),
    };
  }

  /** Fields that are shared across locales and must not be overwritten by the overlay. */
  private static sharedFields(canonical: Raw): Raw {
    return {
      slug: canonical['slug'],
      isPinned: canonical['isPinned'],
      publishedAt: canonical['publishedAt'],
      heroImage: canonical['heroImage'],
      channels: canonical['channels'],
      authors: canonical['authors'],
      sourceUrl: canonical['sourceUrl'],
    };
  }

  async getNewsBySlug(
    locale: LocaleResolution,
    slug: string,
  ): Promise<{
    data: NewsDetailDto;
    translationFallback: boolean;
    droppedBlockTypes: string[];
  }> {
    const populate = {
      channels: { fields: ['slug', 'name', 'colorHex'] },
      authors: { fields: ['name', 'role'] },
      heroImage: { fields: ['url', 'alternativeText', 'width', 'height'] },
    };

    const canonical = await this.fetch('/api/news-articles', {
      filters: { slug: { $eq: slug } },
      populate,
      pagination: { pageSize: 1 },
      locale: CANONICAL_LOCALE,
    });

    const base = canonical[0];
    if (!base) {
      throw new ApiError('NEWS_ARTICLE_NOT_FOUND', locale.resolvedLocale);
    }

    let localised: Raw | undefined;
    if (locale.resolvedLocale !== CANONICAL_LOCALE) {
      const translated = await this.fetch('/api/news-articles', {
        filters: { slug: { $eq: slug } },
        populate,
        pagination: { pageSize: 1 },
        locale: locale.resolvedLocale,
      });
      localised = translated[0];
    }

    const merged = localised ? { ...base, ...localised, ...NewsService.sharedFields(base) } : base;

    const { article, droppedBlockTypes } = mapNewsDetail(merged);

    return {
      data: article,
      translationFallback: locale.resolvedLocale !== CANONICAL_LOCALE && !localised,
      droppedBlockTypes,
    };
  }
}
