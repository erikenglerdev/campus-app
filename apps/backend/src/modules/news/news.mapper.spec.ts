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
        url: 'https://cdn.example/hero.jpg',
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
      const result = mapNewsListItem(raw);
      expect(result).toEqual({
        slug: 'semesterstart-2026',
        title: 'Semesterstart',
        teaser: 'Kurzfassung.',
        publishedAt: '2026-07-20T09:00:00.000Z',
        isPinned: true,
        heroImage: {
          url: 'https://cdn.example/hero.jpg',
          alternativeText: 'Ein Bild',
          width: 1600,
          height: 900,
        },
        channels: [{ slug: 'campus-news', name: 'Campus News', colorHex: '#5B3FD0' }],
        authors: [{ name: 'Redaktion', role: 'Redaktion' }],
        sourceName: 'Hochschule Anhalt',
        sourceUrl: 'https://www.hs-anhalt.de/news',
      });
    });

    it('drops a non-https source url rather than forwarding it', () => {
      expect(
        mapNewsListItem({ ...raw, sourceUrl: 'http://insecure.example' }).sourceUrl,
      ).toBeNull();

      expect(mapNewsListItem({ ...raw, sourceUrl: 'javascript:alert(1)' }).sourceUrl).toBeNull();
    });

    it('drops a hero image that is not served over https', () => {
      expect(
        mapNewsListItem({ ...raw, heroImage: { url: 'http://cdn.example/x.jpg' } }).heroImage,
      ).toBeNull();
    });

    it('handles a missing hero image, authors and channels', () => {
      const result = mapNewsListItem({
        ...raw,
        heroImage: null,
        authors: undefined,
        channels: null,
      });
      expect(result.heroImage).toBeNull();
      expect(result.authors).toEqual([]);
      expect(result.channels).toEqual([]);
    });

    it('never leaks Strapi internals including nested relations', () => {
      const serialized = JSON.stringify(mapNewsListItem(raw));
      for (const leak of ['documentId', 'formats', 'attributes', '"id"']) {
        expect(serialized).not.toContain(leak);
      }
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
