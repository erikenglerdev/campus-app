import { mapChannel, mapNewsDetail, mapNewsListItem } from './news.mapper';

describe('news mappers', () => {
  describe('mapChannel', () => {
    const raw = {
      id: 1,
      documentId: 'doc_abc',
      name: 'Campus News',
      slug: 'campus-news',
      description: 'Rund um den Campus.',
      iconKey: 'campus',
      colorHex: '#5B3FD0',
      sortOrder: 10,
      isActive: true,
      defaultSubscribed: true,
      locale: 'de',
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-02T00:00:00.000Z',
      publishedAt: '2026-01-02T00:00:00.000Z',
      localizations: [{ id: 2, documentId: 'doc_abc', locale: 'en' }],
    };

    it('maps the public fields', () => {
      expect(mapChannel(raw)).toEqual({
        slug: 'campus-news',
        name: 'Campus News',
        description: 'Rund um den Campus.',
        iconKey: 'campus',
        colorHex: '#5B3FD0',
        sortOrder: 10,
        defaultSubscribed: true,
      });
    });

    it('never leaks Strapi internals', () => {
      const serialized = JSON.stringify(mapChannel(raw));
      for (const leak of ['documentId', 'localizations', 'createdAt', 'updatedAt', 'publishedAt']) {
        expect(serialized).not.toContain(leak);
      }
      expect(mapChannel(raw)).not.toHaveProperty('id');
      expect(mapChannel(raw)).not.toHaveProperty('isActive');
    });

    it('normalises a missing description to null', () => {
      expect(mapChannel({ ...raw, description: undefined }).description).toBeNull();
    });
  });

  describe('mapNewsListItem', () => {
    const raw = {
      id: 5,
      documentId: 'doc_news',
      title: 'Semesterstart',
      slug: 'semesterstart-2026',
      teaser: 'Kurzfassung.',
      isPinned: true,
      publishedAt: '2026-07-20T09:00:00.000Z',
      sourceName: 'Hochschule Anhalt',
      sourceUrl: 'https://www.hs-anhalt.de/news',
      heroImage: {
        id: 9,
        documentId: 'doc_img',
        url: '/uploads/hero_abc123.jpg',
        alternativeText: 'Ein Bild',
        width: 1600,
        height: 900,
        formats: { thumbnail: { url: 'https://cdn.example/t.jpg' } },
      },
      channels: [
        { id: 1, documentId: 'c1', slug: 'campus-news', name: 'Campus News', colorHex: '#5B3FD0' },
      ],
      authors: [{ id: 3, documentId: 'a1', name: 'Redaktion', role: 'Redaktion' }],
    };

    it('maps the public listing shape', () => {
      const result = mapNewsListItem(raw).item;
      expect(result).toEqual({
        slug: 'semesterstart-2026',
        title: 'Semesterstart',
        teaser: 'Kurzfassung.',
        publishedAt: '2026-07-20T09:00:00.000Z',
        isPinned: true,
        heroImage: {
          // Served by this API. The client never fetches from Strapi, and the
          // relative path the CMS publishes would be unusable on a phone.
          url: '/v1/media/uploads/hero_abc123.jpg',
          alternativeText: 'Ein Bild',
          width: 1600,
          height: 900,
        },
        channels: [{ slug: 'campus-news', name: 'Campus News', colorHex: '#5B3FD0' }],
        authors: [{ name: 'Redaktion', role: 'Redaktion' }],
        sourceName: 'Hochschule Anhalt',
        sourceUrl: 'https://www.hs-anhalt.de/news',
        // The fixture has no content; an article without blocks is not an
        // error, it is an article nobody has written a body for yet.
        content: [],
      });
    });

    it('drops a non-https source url rather than forwarding it', () => {
      expect(
        mapNewsListItem({ ...raw, sourceUrl: 'http://insecure.example' }).item.sourceUrl,
      ).toBeNull();

      expect(
        mapNewsListItem({ ...raw, sourceUrl: 'javascript:alert(1)' }).item.sourceUrl,
      ).toBeNull();
    });

    it('drops a hero image that is not an upload of the CMS', () => {
      // The media route only serves the upload directory; anything else would
      // turn it into an open proxy.
      expect(
        mapNewsListItem({ ...raw, heroImage: { url: 'https://cdn.example/etc/passwd' } }).item
          .heroImage,
      ).toBeNull();
      expect(
        mapNewsListItem({ ...raw, heroImage: { url: '/uploads/../secret.jpg' } }).item.heroImage,
      ).toBeNull();
    });

    it('never leaks the CMS address into a hero image', () => {
      const item = mapNewsListItem({
        ...raw,
        heroImage: { url: 'https://cms.internal/uploads/hero.jpg' },
      }).item;
      expect(item.heroImage?.url).toBe('/v1/media/uploads/hero.jpg');
      expect(JSON.stringify(item)).not.toContain('cms.internal');
    });

    it('handles a missing hero image, authors and channels', () => {
      const result = mapNewsListItem({
        ...raw,
        heroImage: null,
        authors: undefined,
        channels: null,
      }).item;
      expect(result.heroImage).toBeNull();
      expect(result.authors).toEqual([]);
      expect(result.channels).toEqual([]);
    });

    it('never leaks Strapi internals including nested relations', () => {
      const serialized = JSON.stringify(mapNewsListItem(raw).item);
      for (const leak of ['documentId', 'formats', 'attributes', '"id"']) {
        expect(serialized).not.toContain(leak);
      }
    });

    it('carries the sanitised content, so the list needs no detail request', () => {
      // The feed renders the article inline. Fetching each one separately
      // would be a request per visible card.
      const result = mapNewsListItem({
        ...raw,
        content: [
          { type: 'paragraph', children: [{ type: 'text', text: 'Hallo' }] },
          { type: 'future-embed', payload: 1 },
        ],
      });

      expect(result.item.content).toEqual([
        { type: 'paragraph', children: [{ type: 'text', text: 'Hallo' }] },
      ]);
      expect(result.droppedBlockTypes).toEqual(['future-embed']);
    });

    it('yields empty content rather than throwing when there is none', () => {
      expect(mapNewsListItem({ ...raw, content: null }).item.content).toEqual([]);
    });
  });

  describe('mapNewsDetail', () => {
    it('adds sanitised content and reports dropped block types', () => {
      const result = mapNewsDetail({
        title: 'T',
        slug: 's',
        teaser: 'x',
        isPinned: false,
        publishedAt: '2026-07-20T09:00:00.000Z',
        content: [
          { type: 'paragraph', children: [{ type: 'text', text: 'Hallo' }] },
          { type: 'future-embed', payload: 1 },
        ],
      });

      expect(result.article.content).toEqual([
        { type: 'paragraph', children: [{ type: 'text', text: 'Hallo' }] },
      ]);
      expect(result.droppedBlockTypes).toEqual(['future-embed']);
    });

    it('yields empty content rather than throwing when content is missing', () => {
      const result = mapNewsDetail({
        title: 'T',
        slug: 's',
        teaser: 'x',
        isPinned: false,
        publishedAt: null,
        content: null,
      });
      expect(result.article.content).toEqual([]);
    });
  });
});
