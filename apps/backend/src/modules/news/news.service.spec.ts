import { ApiError } from '../../common/errors/api-error';
import { StrapiClient, StrapiRequestError } from '../strapi/strapi.client';
import { NewsService } from './news.service';

interface Call {
  path: string;
  query: Record<string, unknown>;
}

function makeClient(handler: (call: Call) => unknown) {
  const calls: Call[] = [];
  const client = {
    get: jest.fn(async (path: string, query: Record<string, unknown>) => {
      const call = { path, query };
      calls.push(call);
      return handler(call);
    }),
  } as unknown as StrapiClient;
  return { client, calls };
}

const channel = (slug: string, over: Record<string, unknown> = {}) => ({
  slug,
  name: slug,
  iconKey: 'campus',
  colorHex: '#5B3FD0',
  sortOrder: 0,
  isActive: true,
  defaultSubscribed: false,
  ...over,
});

const article = (slug: string, over: Record<string, unknown> = {}) => ({
  slug,
  title: `Title ${slug}`,
  teaser: 'teaser',
  isPinned: false,
  publishedAt: '2026-07-01T00:00:00.000Z',
  channels: [],
  authors: [],
  ...over,
});

const de = { requestedLocale: 'de', resolvedLocale: 'de' } as const;
const en = { requestedLocale: 'en', resolvedLocale: 'en' } as const;

describe('NewsService', () => {
  describe('getChannels', () => {
    it('sorts by sortOrder then name and maps to the public shape', async () => {
      const { client } = makeClient(() => ({
        data: [
          channel('b', { sortOrder: 10, name: 'B' }),
          channel('a', { sortOrder: 5, name: 'A' }),
          channel('c', { sortOrder: 10, name: 'A-first' }),
        ],
      }));
      const service = new NewsService(client);

      const result = await service.getChannels(de);

      expect(result.data.map((c) => c.slug)).toEqual(['a', 'c', 'b']);
    });

    it('asks Strapi only for active channels', async () => {
      const { client, calls } = makeClient(() => ({ data: [] }));
      await new NewsService(client).getChannels(de);

      expect(JSON.stringify(calls[0]!.query)).toContain('isActive');
    });

    it('marks a translation fallback when an English channel is missing', async () => {
      const { client } = makeClient(({ query }) =>
        query['locale'] === 'en'
          ? { data: [] }
          : { data: [channel('campus-news', { name: 'Campus News' })] },
      );

      const result = await new NewsService(client).getChannels(en);

      expect(result.data[0]!.name).toBe('Campus News');
      expect(result.translationFallback).toBe(true);
    });

    it('reports no fallback when the English translation exists', async () => {
      const { client } = makeClient(({ query }) =>
        query['locale'] === 'en'
          ? { data: [channel('campus-news', { name: 'Campus News EN' })] }
          : { data: [channel('campus-news', { name: 'Campus News DE' })] },
      );

      const result = await new NewsService(client).getChannels(en);

      expect(result.data[0]!.name).toBe('Campus News EN');
      expect(result.translationFallback).toBe(false);
    });

    it('translates an upstream timeout into a 504', async () => {
      const client = {
        get: jest.fn(async () => {
          throw new StrapiRequestError('timeout', 'timed out');
        }),
      } as unknown as StrapiClient;

      await expect(new NewsService(client).getChannels(de)).rejects.toMatchObject({
        code: 'UPSTREAM_TIMEOUT',
      });
    });

    it('translates an upstream outage into a 503', async () => {
      const client = {
        get: jest.fn(async () => {
          throw new StrapiRequestError('unavailable', 'down');
        }),
      } as unknown as StrapiClient;

      await expect(new NewsService(client).getChannels(de)).rejects.toBeInstanceOf(ApiError);
    });
  });

  describe('getNews channel filter contract', () => {
    it('returns an empty list WITHOUT calling Strapi when channels is present but empty', async () => {
      const { client, calls } = makeClient(() => ({ data: [] }));

      const result = await new NewsService(client).getNews(de, {
        channels: [],
        channelsParamPresent: true,
        page: 1,
        pageSize: 20,
      });

      expect(result.data).toEqual([]);
      expect(result.pagination.total).toBe(0);
      expect(calls).toHaveLength(0);
    });

    it('covers all ACTIVE channels when the parameter is absent, without naming slugs', async () => {
      const { client, calls } = makeClient(() => ({ data: [article('a')] }));

      await new NewsService(client).getNews(de, {
        channels: [],
        channelsParamPresent: false,
        page: 1,
        pageSize: 20,
      });

      // docs/api.md §5: an absent parameter means "all active channels" — so the
      // query restricts to active channels but pins no individual slug.
      const serialized = JSON.stringify(calls[0]!.query);
      expect(serialized).toContain('isActive');
      expect(serialized).not.toContain('$in');
    });

    it('filters by the requested channel slugs', async () => {
      const { client, calls } = makeClient(() => ({ data: [] }));

      await new NewsService(client).getNews(de, {
        channels: ['campus-news', 'fb5-news'],
        channelsParamPresent: true,
        page: 1,
        pageSize: 20,
      });

      const serialized = JSON.stringify(calls[0]!.query);
      expect(serialized).toContain('campus-news');
      expect(serialized).toContain('fb5-news');
    });
  });

  describe('getNews result shaping', () => {
    it('deduplicates an article that matches several requested channels', async () => {
      const { client } = makeClient(() => ({
        data: [article('same'), article('same'), article('other')],
      }));

      const result = await new NewsService(client).getNews(de, {
        channels: ['a', 'b'],
        channelsParamPresent: true,
        page: 1,
        pageSize: 20,
      });

      // Deduplicated to two entries; ties then order by slug ascending per contract.
      expect(result.data).toHaveLength(2);
      expect(result.data.map((a) => a.slug)).toEqual(['other', 'same']);
    });

    it('sorts pinned first, then newest, then slug for a stable order', async () => {
      const { client } = makeClient(() => ({
        data: [
          article('old', { publishedAt: '2026-01-01T00:00:00.000Z' }),
          article('pinned-b', { isPinned: true, publishedAt: '2026-01-01T00:00:00.000Z' }),
          article('new', { publishedAt: '2026-06-01T00:00:00.000Z' }),
          article('pinned-a', { isPinned: true, publishedAt: '2026-01-01T00:00:00.000Z' }),
        ],
      }));

      const result = await new NewsService(client).getNews(de, {
        channels: [],
        channelsParamPresent: false,
        page: 1,
        pageSize: 20,
      });

      expect(result.data.map((a) => a.slug)).toEqual(['pinned-a', 'pinned-b', 'new', 'old']);
    });

    it('reports pagination from the upstream total', async () => {
      const { client } = makeClient(() => ({
        data: [article('a')],
        meta: { pagination: { page: 2, pageSize: 5, pageCount: 4, total: 17 } },
      }));

      const result = await new NewsService(client).getNews(de, {
        channels: [],
        channelsParamPresent: false,
        page: 2,
        pageSize: 5,
      });

      expect(result.pagination).toEqual({ page: 2, pageSize: 5, total: 17, totalPages: 4 });
    });

    it('keeps the German text and flags a fallback when an article lacks English', async () => {
      const { client } = makeClient(({ query }) =>
        query['locale'] === 'en'
          ? { data: [article('translated', { title: 'Translated EN' })] }
          : {
              data: [
                article('translated', { title: 'Übersetzt DE' }),
                article('untranslated', { title: 'Nur Deutsch' }),
              ],
            },
      );

      const result = await new NewsService(client).getNews(en, {
        channels: [],
        channelsParamPresent: false,
        page: 1,
        pageSize: 20,
      });

      const bySlug = Object.fromEntries(result.data.map((a) => [a.slug, a.title]));
      expect(bySlug['translated']).toBe('Translated EN');
      expect(bySlug['untranslated']).toBe('Nur Deutsch');
      expect(result.translationFallback).toBe(true);
    });
  });

  describe('getNewsBySlug', () => {
    it('returns the sanitised detail article', async () => {
      const { client } = makeClient(() => ({
        data: [
          article('a', {
            content: [{ type: 'paragraph', children: [{ type: 'text', text: 'Hi' }] }],
          }),
        ],
      }));

      const result = await new NewsService(client).getNewsBySlug(de, 'a');

      expect(result.data.slug).toBe('a');
      expect(result.data.content).toHaveLength(1);
    });

    it('raises a 404 for an unknown slug', async () => {
      const { client } = makeClient(() => ({ data: [] }));

      await expect(new NewsService(client).getNewsBySlug(de, 'nope')).rejects.toMatchObject({
        code: 'NEWS_ARTICLE_NOT_FOUND',
      });
    });

    it('falls back to German content and flags it', async () => {
      const { client } = makeClient(({ query }) =>
        query['locale'] === 'en' ? { data: [] } : { data: [article('a', { title: 'Deutsch' })] },
      );

      const result = await new NewsService(client).getNewsBySlug(en, 'a');

      expect(result.data.title).toBe('Deutsch');
      expect(result.translationFallback).toBe(true);
    });
  });
});
