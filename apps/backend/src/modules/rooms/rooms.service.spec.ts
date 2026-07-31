import { ApiError } from '../../common/errors/api-error';
import { StrapiClient, StrapiRequestError } from '../strapi/strapi.client';
import { RoomsService } from './rooms.service';

function makeClient(handler: (query: Record<string, unknown>) => unknown) {
  return {
    get: jest.fn(async (_path: string, query: Record<string, unknown>) => handler(query)),
  } as unknown as StrapiClient;
}

const room = (roomKey: string, over: Record<string, unknown> = {}) => ({
  roomKey,
  roomNumber: 'B.201',
  buildingKey: 'demo-north',
  buildingNameDe: 'Demogebäude Nord (fiktiv)',
  buildingNameEn: 'Demo building north (fictional)',
  floorKey: 'demo-north-level2',
  floorLevel: 2,
  floorNameDe: '2. Obergeschoss',
  floorNameEn: 'Second floor',
  roomType: 'lecture',
  mapVersion: 'demo-1',
  sortOrder: 10,
  catalogActive: true,
  isVisible: true,
  ...over,
});

const de = { requestedLocale: 'de', resolvedLocale: 'de' } as const;
const en = { requestedLocale: 'en', resolvedLocale: 'en' } as const;

describe('RoomsService', () => {
  describe('listRooms', () => {
    it('serves the German names for locale=de', async () => {
      const client = makeClient(() => ({ data: [room('a')] }));
      const result = await new RoomsService(client).listRooms(de, {});

      expect(result.data[0]!.buildingName).toBe('Demogebäude Nord (fiktiv)');
      expect(result.data[0]!.floorName).toBe('2. Obergeschoss');
      expect(result.translationFallback).toBe(false);
    });

    it('serves the English names for locale=en', async () => {
      const client = makeClient(() => ({ data: [room('a')] }));
      const result = await new RoomsService(client).listRooms(en, {});

      expect(result.data[0]!.buildingName).toBe('Demo building north (fictional)');
      expect(result.data[0]!.floorName).toBe('Second floor');
      expect(result.translationFallback).toBe(false);
    });

    it('falls back to German editorial text and flags it', async () => {
      const client = makeClient(() => ({
        data: [room('a', { displayNameDe: 'Großer Hörsaal', displayNameEn: null })],
      }));
      const result = await new RoomsService(client).listRooms(en, {});

      expect(result.data[0]!.displayName).toBe('Großer Hörsaal');
      expect(result.translationFallback).toBe(true);
    });

    it('does not flag a fallback when nothing was translated in the first place', async () => {
      const client = makeClient(() => ({ data: [room('a')] }));
      const result = await new RoomsService(client).listRooms(en, {});
      expect(result.translationFallback).toBe(false);
    });

    it('requests only catalogue-active AND visible rooms', async () => {
      const seen: Record<string, unknown>[] = [];
      const client = makeClient((query) => {
        seen.push(query);
        return { data: [] };
      });

      await new RoomsService(client).listRooms(de, {});

      const filters = seen[0]!.filters as Record<string, unknown>;
      expect(filters).toMatchObject({
        catalogActive: { $eq: true },
        isVisible: { $eq: true },
      });
    });

    it('applies validated building and floor filters', async () => {
      const seen: Record<string, unknown>[] = [];
      const client = makeClient((query) => {
        seen.push(query);
        return { data: [] };
      });

      await new RoomsService(client).listRooms(de, {
        buildingKey: 'demo-north',
        floorKey: 'demo-north-level2',
      });

      expect(seen[0]!.filters).toMatchObject({
        buildingKey: { $eq: 'demo-north' },
        floorKey: { $eq: 'demo-north-level2' },
      });
    });

    it('sorts by sortOrder then roomNumber', async () => {
      const client = makeClient(() => ({
        data: [
          room('c', { sortOrder: 20, roomNumber: 'B.203' }),
          room('a', { sortOrder: 10, roomNumber: 'B.201' }),
          room('b', { sortOrder: 20, roomNumber: 'B.202' }),
        ],
      }));

      const result = await new RoomsService(client).listRooms(de, {});
      expect(result.data.map((r) => r.roomKey)).toEqual(['a', 'b', 'c']);
    });

    it('drops a row that has no roomKey rather than serving a broken entry', async () => {
      const client = makeClient(() => ({ data: [room('a'), { roomNumber: 'X' }] }));
      const result = await new RoomsService(client).listRooms(de, {});
      expect(result.data).toHaveLength(1);
    });

    it('leaks no Strapi internals', async () => {
      const client = makeClient(() => ({
        data: [
          {
            ...room('a'),
            documentId: 'strapi-doc-id',
            id: 17,
            createdAt: 'x',
            localizations: [],
            contactPersons: [{ id: 3, name: 'X' }],
          },
        ],
      }));

      const result = await new RoomsService(client).listRooms(de, {});
      const serialised = JSON.stringify(result.data);

      for (const forbidden of ['documentId', 'localizations', 'createdAt', 'strapi-doc-id']) {
        expect(serialised).not.toContain(forbidden);
      }
    });

    it('maps an upstream timeout to UPSTREAM_TIMEOUT', async () => {
      const client = {
        get: jest.fn(async () => {
          throw new StrapiRequestError('timeout', 'timed out');
        }),
      } as unknown as StrapiClient;

      await expect(new RoomsService(client).listRooms(de, {})).rejects.toBeInstanceOf(ApiError);
    });
  });

  describe('getRoom', () => {
    it('returns the requested room', async () => {
      const client = makeClient(() => ({ data: [room('demo-north-level2-b201')] }));
      const result = await new RoomsService(client).getRoom(de, 'demo-north-level2-b201');
      expect(result.data.roomKey).toBe('demo-north-level2-b201');
    });

    it('rejects an unknown roomKey with ROOM_NOT_FOUND', async () => {
      const client = makeClient(() => ({ data: [] }));
      await expect(new RoomsService(client).getRoom(de, 'nope')).rejects.toMatchObject({
        code: 'ROOM_NOT_FOUND',
      });
    });

    it('never serves an invisible or deactivated room', async () => {
      const seen: Record<string, unknown>[] = [];
      const client = makeClient((query) => {
        seen.push(query);
        return { data: [] };
      });

      await expect(new RoomsService(client).getRoom(de, 'x')).rejects.toBeInstanceOf(ApiError);
      expect(seen[0]!.filters).toMatchObject({
        catalogActive: { $eq: true },
        isVisible: { $eq: true },
      });
    });
  });
});
