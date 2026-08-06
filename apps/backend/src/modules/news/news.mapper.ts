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
import { publicMediaUrl } from '../media/media.path';

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
  // Served by this API rather than linked straight to Strapi: the app must not
  // talk to the CMS (CLAUDE.md §2.1), and the local upload provider publishes
  // relative URLs that a mobile client cannot resolve at all.
  const url = publicMediaUrl(value['url']);
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

/**
 * Maps one article, content included.
 *
 * The content travels with the LIST entry, not only with the detail: the app's
 * feed renders each article inline, so fetching them one by one would be a
 * request per visible card. Sanitising happens here, once — unsanitised Strapi
 * blocks never reach a client.
 */
export function mapNewsListItem(raw: Raw): {
  item: NewsListItemDto;
  droppedBlockTypes: string[];
} {
  const { blocks, droppedBlockTypes } = sanitizeBlocks(raw['content']);
  return {
    item: {
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
      content: blocks,
    },
    droppedBlockTypes,
  };
}

/**
 * The detail shape is the list shape.
 *
 * Kept as its own function because the endpoint is part of the published
 * contract and callers of it read better this way.
 */
export function mapNewsDetail(raw: Raw): {
  article: NewsDetailDto;
  droppedBlockTypes: string[];
} {
  const { item, droppedBlockTypes } = mapNewsListItem(raw);
  return { article: item, droppedBlockTypes };
}
