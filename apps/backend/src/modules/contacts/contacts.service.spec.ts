import { StrapiClient, StrapiRequestError } from '../strapi/strapi.client';
import { ContactsService } from './contacts.service';

function makeClient(handler: (query: Record<string, unknown>) => unknown) {
  return {
    get: jest.fn(async (_path: string, query: Record<string, unknown>) => handler(query)),
  } as unknown as StrapiClient;
}

const area = (slug: string, over: Record<string, unknown> = {}) => ({
  slug,
  name: slug,
  shortDescription: 'kurz',
  iconKey: 'contact',
  sortOrder: 0,
  isActive: true,
  isDemoContent: false,
  persons: [],
  ...over,
});

const de = { requestedLocale: 'de', resolvedLocale: 'de' } as const;
const en = { requestedLocale: 'en', resolvedLocale: 'en' } as const;

describe('ContactsService', () => {
  describe('listAreas', () => {
    it('sorts by sortOrder then name', async () => {
      const client = makeClient(() => ({
        data: [
          area('b', { sortOrder: 20, name: 'B' }),
          area('a', { sortOrder: 10, name: 'A' }),
          area('c', { sortOrder: 20, name: 'A-first' }),
        ],
      }));

      const result = await new ContactsService(client).listAreas(de);
      expect(result.data.map((a) => a.slug)).toEqual(['a', 'c', 'b']);
    });

    it('reports an area without persons as fully valid with personCount 0', async () => {
      const client = makeClient(() => ({ data: [area('ssc', { persons: [] })] }));

      const result = await new ContactsService(client).listAreas(de);

      expect(result.data[0]!.personCount).toBe(0);
      expect(result.data[0]!.slug).toBe('ssc');
    });

    it('counts only ACTIVE persons', async () => {
      const client = makeClient(() => ({
        data: [
          area('x', {
            persons: [
              { name: 'A', isActive: true },
              { name: 'B', isActive: false },
              { name: 'C', isActive: true },
            ],
          }),
        ],
      }));

      const result = await new ContactsService(client).listAreas(de);
      expect(result.data[0]!.personCount).toBe(2);
    });

    it('requests only active areas', async () => {
      const seen: Record<string, unknown>[] = [];
      const client = makeClient((query) => {
        seen.push(query);
        return { data: [] };
      });

      await new ContactsService(client).listAreas(de);
      expect(JSON.stringify(seen[0])).toContain('isActive');
    });

    it('surfaces the demo-content marker', async () => {
      const client = makeClient(() => ({ data: [area('x', { isDemoContent: true })] }));
      const result = await new ContactsService(client).listAreas(de);
      expect(result.data[0]!.isDemoContent).toBe(true);
    });

    it('keeps German text and flags fallback when English is missing', async () => {
      const client = makeClient((query) =>
        query['locale'] === 'en' ? { data: [] } : { data: [area('x', { name: 'Deutsch' })] },
      );

      const result = await new ContactsService(client).listAreas(en);

      expect(result.data[0]!.name).toBe('Deutsch');
      expect(result.translationFallback).toBe(true);
    });

    it('maps an upstream timeout to a 504', async () => {
      const client = {
        get: jest.fn(async () => {
          throw new StrapiRequestError('timeout', 'nope');
        }),
      } as unknown as StrapiClient;

      await expect(new ContactsService(client).listAreas(de)).rejects.toMatchObject({
        code: 'UPSTREAM_TIMEOUT',
      });
    });
  });

  describe('field hygiene', () => {
    it('drops unusable contact fields instead of forwarding them', async () => {
      const client = makeClient(() => ({
        data: [
          area('x', {
            generalEmail: 'not-an-email',
            website: 'http://insecure.example',
            appointmentUrl: 'ftp://x',
            phone: '   ',
          }),
        ],
      }));

      const result = await new ContactsService(client).listAreas(de);
      const item = result.data[0]!;

      expect(item.generalEmail).toBeNull();
      expect(item.website).toBeNull();
      expect(item.appointmentUrl).toBeNull();
      expect(item.phone).toBeNull();
    });

    it('keeps valid contact fields', async () => {
      const client = makeClient(() => ({
        data: [
          area('x', {
            generalEmail: 'kontakt@example.org',
            website: 'https://example.org',
            phone: '+49 3496 000',
          }),
        ],
      }));

      const item = (await new ContactsService(client).listAreas(de)).data[0]!;

      expect(item.generalEmail).toBe('kontakt@example.org');
      expect(item.website).toBe('https://example.org');
      expect(item.phone).toBe('+49 3496 000');
    });

    it('never leaks Strapi internals', async () => {
      const client = makeClient(() => ({
        data: [area('x', { documentId: 'doc_1', localizations: [{ id: 2 }] })],
      }));

      const result = await new ContactsService(client).listAreas(de);
      const serialized = JSON.stringify(result.data);

      expect(serialized).not.toContain('documentId');
      expect(serialized).not.toContain('localizations');
    });
  });

  describe('getArea', () => {
    it('returns an area with its active persons sorted', async () => {
      const client = makeClient(() => ({
        data: [
          area('x', {
            description: [{ type: 'paragraph', children: [{ type: 'text', text: 'Info' }] }],
            persons: [
              { name: 'Zeta', isActive: true, sortOrder: 20 },
              { name: 'Alpha', isActive: true, sortOrder: 10 },
              { name: 'Hidden', isActive: false, sortOrder: 1 },
            ],
          }),
        ],
      }));

      const result = await new ContactsService(client).getArea(de, 'x');

      expect(result.data.persons.map((p) => p.name)).toEqual(['Alpha', 'Zeta']);
      expect(result.data.description).toHaveLength(1);
    });

    it('works for an area with no persons at all', async () => {
      const client = makeClient(() => ({ data: [area('studentenwerk', { persons: [] })] }));

      const result = await new ContactsService(client).getArea(de, 'studentenwerk');

      expect(result.data.persons).toEqual([]);
      expect(result.data.slug).toBe('studentenwerk');
    });

    it('raises a 404 for an unknown slug', async () => {
      const client = makeClient(() => ({ data: [] }));

      await expect(new ContactsService(client).getArea(de, 'nope')).rejects.toMatchObject({
        code: 'CONTACT_AREA_NOT_FOUND',
      });
    });

    it('drops unknown description block types and reports them', async () => {
      const client = makeClient(() => ({
        data: [area('x', { description: [{ type: 'paragraph' }, { type: 'future-thing' }] })],
      }));

      const result = await new ContactsService(client).getArea(de, 'x');
      expect(result.droppedBlockTypes).toEqual(['future-thing']);
    });
  });

  describe('room references', () => {
    const demoRoom = (over: Record<string, unknown> = {}) => ({
      roomKey: 'demo-north-level2-b201',
      roomNumber: 'B.201',
      buildingKey: 'demo-north',
      buildingNameDe: 'Demogebäude Nord (fiktiv)',
      buildingNameEn: 'Demo building north (fictional)',
      floorKey: 'demo-north-level2',
      floorLevel: 2,
      floorNameDe: '2. Obergeschoss',
      floorNameEn: 'Second floor',
      catalogActive: true,
      isVisible: true,
      ...over,
    });

    it('serves an empty room list for an area without rooms', async () => {
      const client = makeClient(() => ({ data: [area('ssc')] }));
      const result = await new ContactsService(client).getArea(de, 'ssc');
      expect(result.data.rooms).toEqual([]);
    });

    it('serves an empty room list for a person without rooms', async () => {
      const client = makeClient(() => ({
        data: [area('x', { persons: [{ name: 'A', isActive: true }] })],
      }));
      const result = await new ContactsService(client).getArea(de, 'x');
      expect(result.data.persons[0]!.rooms).toEqual([]);
    });

    it('maps the rooms of an area', async () => {
      const client = makeClient(() => ({ data: [area('x', { rooms: [demoRoom()] })] }));
      const result = await new ContactsService(client).getArea(de, 'x');

      expect(result.data.rooms).toHaveLength(1);
      expect(result.data.rooms[0]).toMatchObject({
        roomKey: 'demo-north-level2-b201',
        roomNumber: 'B.201',
        buildingName: 'Demogebäude Nord (fiktiv)',
        floorName: '2. Obergeschoss',
        floorLevel: 2,
      });
    });

    it('maps the rooms of a person', async () => {
      const client = makeClient(() => ({
        data: [area('x', { persons: [{ name: 'A', isActive: true, rooms: [demoRoom()] }] })],
      }));
      const result = await new ContactsService(client).getArea(de, 'x');
      expect(result.data.persons[0]!.rooms[0]!.roomKey).toBe('demo-north-level2-b201');
    });

    it('localises room names for en', async () => {
      const client = makeClient(() => ({ data: [area('x', { rooms: [demoRoom()] })] }));
      const result = await new ContactsService(client).getArea(en, 'x');

      expect(result.data.rooms[0]!.buildingName).toBe('Demo building north (fictional)');
      expect(result.data.rooms[0]!.floorName).toBe('Second floor');
    });

    it('hides a deactivated or invisible room even through a relation', async () => {
      const client = makeClient(() => ({
        data: [
          area('x', {
            rooms: [
              demoRoom({ roomKey: 'gone', catalogActive: false }),
              demoRoom({ roomKey: 'hidden', isVisible: false }),
              demoRoom({ roomKey: 'shown' }),
            ],
          }),
        ],
      }));

      const result = await new ContactsService(client).getArea(de, 'x');
      expect(result.data.rooms.map((r) => r.roomKey)).toEqual(['shown']);
    });

    it('never exposes a Strapi id through a room reference', async () => {
      const client = makeClient(() => ({
        data: [area('x', { rooms: [{ ...demoRoom(), id: 42, documentId: 'doc-42' }] })],
      }));

      const result = await new ContactsService(client).getArea(de, 'x');
      const serialised = JSON.stringify(result.data.rooms);
      expect(serialised).not.toContain('documentId');
      expect(serialised).not.toContain('doc-42');
    });
  });
});
