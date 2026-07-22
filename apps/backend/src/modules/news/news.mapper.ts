import { sanitizeBlocks } from '../../common/content/content-blocks';
import {
  AuthorDto,
  ImageDto,
  NewsChannelDto,
  NewsChannelRefDto,
  NewsDetailDto,
  NewsListItemDto,
} from './news.types';
import { asString } from '../../common/util/coerce';

/**
 * Strapi -> public DTO mapping.
 *
 * This is the single boundary where upstream structures are dropped. Every
 * field of the public contract is written out explicitly rather than spread
 * from the source object, so a new Strapi field can never leak by accident.
 */

type Raw = Record<string, unknown>;

function isRecord(value: unknown): value is Raw {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function str(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null;
}

function num(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

/** Only https URLs are forwarded; anything else becomes null. */
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

function mapImage(value: unknown): ImageDto | null {
  if (!isRecord(value)) {
    return null;
  }
  const url = httpsUrl(value['url']);
  if (!url) {
    return null;
  }
  return {
    url,
    alternativeText: str(value['alternativeText']),
    width: num(value['width']),
    height: num(value['height']),
  };
}

export function mapChannel(raw: Raw): NewsChannelDto {
  return {
    slug: asString(raw['slug']),
    name: asString(raw['name']),
    description: str(raw['description']),
    iconKey: asString(raw['iconKey'], 'channel'),
    colorHex: asString(raw['colorHex'], '#5B3FD0'),
    sortOrder: num(raw['sortOrder']) ?? 0,
    defaultSubscribed: raw['defaultSubscribed'] === true,
  };
}

function mapChannelRef(raw: unknown): NewsChannelRefDto | null {
  if (!isRecord(raw)) {
    return null;
  }
  const slug = str(raw['slug']);
  if (!slug) {
    return null;
  }
  return {
    slug,
    name: asString(raw['name']),
    colorHex: asString(raw['colorHex'], '#5B3FD0'),
  };
}

function mapAuthor(raw: unknown): AuthorDto | null {
  if (!isRecord(raw)) {
    return null;
  }
  const name = str(raw['name']);
  if (!name) {
    return null;
  }
  return { name, role: str(raw['role']) };
}

function mapList<T>(value: unknown, map: (entry: unknown) => T | null): T[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map(map).filter((entry): entry is T => entry !== null);
}

export function mapNewsListItem(raw: Raw): NewsListItemDto {
  return {
    slug: asString(raw['slug']),
    title: asString(raw['title']),
    teaser: asString(raw['teaser']),
    publishedAt: str(raw['publishedAt']),
    isPinned: raw['isPinned'] === true,
    heroImage: mapImage(raw['heroImage']),
    channels: mapList(raw['channels'], mapChannelRef),
    authors: mapList(raw['authors'], mapAuthor),
    sourceName: str(raw['sourceName']),
    // A source link is only useful if it is safe to open.
    sourceUrl: httpsUrl(raw['sourceUrl']),
  };
}

export function mapNewsDetail(raw: Raw): {
  article: NewsDetailDto;
  droppedBlockTypes: string[];
} {
  const { blocks, droppedBlockTypes } = sanitizeBlocks(raw['content']);
  return {
    article: { ...mapNewsListItem(raw), content: blocks },
    droppedBlockTypes,
  };
}
