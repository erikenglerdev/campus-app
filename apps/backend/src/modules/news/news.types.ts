import { ContentBlock } from '../../common/content/content-blocks';

/**
 * Public shapes returned by /v1/news*.
 *
 * These are the ONLY news structures that ever leave the process. Strapi's
 * `documentId`, `localizations`, `formats` and friends stop at the mapper.
 */

export interface NewsChannelDto {
  slug: string;
  name: string;
  description: string | null;
  iconKey: string;
  colorHex: string;
  sortOrder: number;
  defaultSubscribed: boolean;
}

export interface ImageDto {
  url: string;
  alternativeText: string | null;
  width: number | null;
  height: number | null;
}

export interface NewsChannelRefDto {
  slug: string;
  name: string;
  colorHex: string;
}

export interface AuthorDto {
  name: string;
  role: string | null;
}

export interface NewsListItemDto {
  slug: string;
  title: string;
  teaser: string;
  publishedAt: string | null;
  isPinned: boolean;
  heroImage: ImageDto | null;
  channels: NewsChannelRefDto[];
  authors: AuthorDto[];
  sourceName: string | null;
  sourceUrl: string | null;
}

export interface NewsDetailDto extends NewsListItemDto {
  content: ContentBlock[];
}
