import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { buildUserTestDataset, UserTestMapCatalog } from './user-test-data.dataset';

const catalog = JSON.parse(
  readFileSync(
    resolve(process.cwd(), '../../packages/campus-map/catalog/campus-map.catalog.json'),
    'utf8',
  ),
) as UserTestMapCatalog;

describe('buildUserTestDataset', () => {
  const input = {
    anchor: new Date('2026-08-06T12:00:00.000Z'),
    catalog,
    canteenSlugs: ['koethen-fasanerieallee', 'koethen-lohmannstrasse'],
  } as const;

  it('is deterministic and uses a reserved negative meal-id namespace', () => {
    const first = buildUserTestDataset(input);
    const second = buildUserTestDataset(input);

    expect(first).toEqual(second);
    expect(first.meals.length).toBeGreaterThan(50);
    expect(first.meals.every((meal) => meal.sourcePlanId < 0)).toBe(true);
    expect(new Set(first.meals.map((meal) => meal.sourcePlanId)).size).toBe(first.meals.length);
  });

  it('provides realistic menu facets, allergens, sprint meals and every price group', () => {
    const dataset = buildUserTestDataset(input);
    const codes = new Set(dataset.meals.flatMap((meal) => meal.ingredientCodes));

    expect(codes).toEqual(expect.objectContaining(new Set(['50', '51', '52', 'A1', 'C', 'F'])));
    expect(dataset.meals.some((meal) => meal.isSprint)).toBe(true);
    expect(
      dataset.meals.every((meal) =>
        ['student', 'employee', 'guest'].every((group) =>
          meal.prices.some((price) => price.group === group),
        ),
      ),
    ).toBe(true);
  });

  it('takes every timetable room from the current fictional building catalogue', () => {
    const dataset = buildUserTestDataset(input);
    const allowedRooms = new Set(
      catalog.rooms
        .filter((room) => room.buildingKey === 'demo-north')
        .map((room) => room.roomNumber),
    );
    const usedRooms = dataset.timetable.entries.flatMap((entry) =>
      entry.rooms.map((room) => room.shortName),
    );

    expect(dataset.timetable.entries.length).toBeGreaterThan(20);
    expect(usedRooms.every((room) => allowedRooms.has(room))).toBe(true);
    expect(usedRooms.some((room) => room.startsWith('B.1'))).toBe(true);
    expect(usedRooms.some((room) => room.startsWith('B.2'))).toBe(true);
  });

  it('does not put a demo or test marker on each visible record', () => {
    const dataset = buildUserTestDataset(input);
    const visibleLabels = [
      ...dataset.meals.flatMap((meal) => [meal.name, meal.subtitle ?? '']),
      dataset.timetable.group.shortName,
      dataset.timetable.group.longName,
      ...dataset.timetable.entries.flatMap((entry) => [entry.title, entry.note ?? '']),
    ];

    expect(visibleLabels.join(' ')).not.toMatch(/\b(?:demo|test)\b/i);
  });

  it('refuses a catalogue without suitable rooms', () => {
    expect(() =>
      buildUserTestDataset({
        ...input,
        catalog: { ...catalog, rooms: [] },
      }),
    ).toThrow(/room/i);
  });
});
