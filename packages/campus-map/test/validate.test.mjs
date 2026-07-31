// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { loadCanonical, validate } from '../src/validate.mjs';

/** A tiny self-contained world: one building, one floor, two rooms. */
function fixture() {
  const catalog = {
    schemaVersion: 1,
    mapVersion: 'test-1',
    notice: 'fictional',
    buildings: [
      { buildingKey: 'b', nameDe: 'B', nameEn: 'B', planKind: 'fictional', sortOrder: 10 },
    ],
    floors: [
      {
        floorKey: 'b-l1',
        buildingKey: 'b',
        level: 1,
        nameDe: 'EG',
        nameEn: 'Ground floor',
        svgPath: 'b/l1.svg',
        viewBox: { minX: 0, minY: 0, width: 100, height: 100 },
        expectedRoomCount: 2,
        sortOrder: 10,
      },
    ],
    rooms: [room('r1', 'R.1', 10), room('r2', 'R.2', 20)],
  };
  return { catalog, svgs: { 'b/l1.svg': svgFor(catalog.rooms) } };
}

function room(key, number, sortOrder) {
  return {
    roomKey: key,
    roomNumber: number,
    buildingKey: 'b',
    floorKey: 'b-l1',
    roomType: 'office',
    svgElementId: `room-${key}`,
    focus: { x: 10, y: 10 },
    bounds: { x: 5, y: 5, width: 10, height: 10 },
    sortOrder,
  };
}

function svgFor(rooms, overrides = {}) {
  const rects = rooms
    .map((r) => {
      const id = overrides[r.roomKey]?.id ?? r.svgElementId;
      const dataKey = overrides[r.roomKey]?.dataKey ?? r.roomKey;
      return `<rect id="${id}" class="room office" x="${r.bounds.x}" y="${r.bounds.y}" width="${r.bounds.width}" height="${r.bounds.height}" data-room-key="${dataKey}" data-room-number="${r.roomNumber}" data-building-key="${r.buildingKey}" data-floor-key="${r.floorKey}" data-focus-x="${r.focus.x}" data-focus-y="${r.focus.y}" />`;
    })
    .join('\n');
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><g id="floor-plan">\n${rects}\n</g></svg>`;
}

const run = ({ catalog, svgs }) => validate(catalog, (path) => svgs[path]);

test('a consistent catalogue and SVG produce no problems', () => {
  assert.deepEqual(run(fixture()).problems, []);
});

test('rejects a duplicated roomKey', () => {
  const f = fixture();
  f.catalog.rooms[1].roomKey = 'r1';
  f.svgs['b/l1.svg'] = svgFor(f.catalog.rooms);
  assert.match(run(f).problems.join('\n'), /duplicate roomKey/i);
});

test('rejects a catalogue room that has no SVG element', () => {
  const f = fixture();
  f.catalog.rooms.push(room('r3', 'R.3', 30));
  f.catalog.floors[0].expectedRoomCount = 3;
  assert.match(run(f).problems.join('\n'), /no SVG element/i);
});

test('rejects an SVG room that is missing from the catalogue', () => {
  const f = fixture();
  f.svgs['b/l1.svg'] = svgFor([...f.catalog.rooms, room('ghost', 'R.9', 90)]);
  assert.match(run(f).problems.join('\n'), /not in the catalogue/i);
});

test('rejects a mismatch between roomKey and the SVG element id', () => {
  const f = fixture();
  f.svgs['b/l1.svg'] = svgFor(f.catalog.rooms, { r1: { id: 'room-somethingelse' } });
  assert.match(run(f).problems.join('\n'), /svgElementId/i);
});

test('rejects a mismatch between roomKey and data-room-key', () => {
  const f = fixture();
  f.svgs['b/l1.svg'] = svgFor(f.catalog.rooms, { r1: { dataKey: 'r9' } });
  assert.match(run(f).problems.join('\n'), /not in the catalogue|data-room-key/i);
});

test('rejects an unknown building reference', () => {
  const f = fixture();
  f.catalog.rooms[0].buildingKey = 'nope';
  assert.match(run(f).problems.join('\n'), /unknown buildingKey/i);
});

test('rejects an unknown floor reference', () => {
  const f = fixture();
  f.catalog.rooms[0].floorKey = 'nope';
  assert.match(run(f).problems.join('\n'), /unknown floorKey/i);
});

test('rejects a focus point outside the viewBox', () => {
  const f = fixture();
  f.catalog.rooms[0].focus = { x: 500, y: 10 };
  f.svgs['b/l1.svg'] = svgFor(f.catalog.rooms);
  assert.match(run(f).problems.join('\n'), /focus/i);
});

test('rejects bounds that leave the viewBox', () => {
  const f = fixture();
  f.catalog.rooms[0].bounds = { x: 95, y: 95, width: 50, height: 50 };
  f.svgs['b/l1.svg'] = svgFor(f.catalog.rooms);
  assert.match(run(f).problems.join('\n'), /bounds/i);
});

test('rejects a room count that differs from the declared expectation', () => {
  const f = fixture();
  f.catalog.floors[0].expectedRoomCount = 3;
  assert.match(run(f).problems.join('\n'), /expected 3 rooms/i);
});

test('rejects unsafe SVG content', () => {
  const f = fixture();
  f.svgs['b/l1.svg'] = f.svgs['b/l1.svg'].replace(
    '<g id="floor-plan">',
    '<script>alert(1)</script><g id="floor-plan">',
  );
  assert.match(run(f).problems.join('\n'), /forbidden element/i);
});

test('rejects an unreadable SVG instead of skipping it', () => {
  const f = fixture();
  f.svgs['b/l1.svg'] = '<svg><g></svg>';
  assert.ok(run(f).problems.length > 0);
});

test('rejects an unknown roomType', () => {
  const f = fixture();
  f.catalog.rooms[0].roomType = 'wellness-area';
  assert.match(run(f).problems.join('\n'), /roomType/i);
});

test('rejects a viewBox that disagrees with the SVG', () => {
  const f = fixture();
  f.catalog.floors[0].viewBox = { minX: 0, minY: 0, width: 999, height: 100 };
  assert.match(run(f).problems.join('\n'), /viewBox/i);
});

// --- the real, committed asset ----------------------------------------------

test('the committed demo catalogue and SVG are consistent, with exactly 30 rooms', () => {
  const { catalog, problems } = loadCanonical();
  assert.deepEqual(problems, [], problems.join('\n'));
  assert.equal(catalog.rooms.length, 30);
  assert.equal(new Set(catalog.rooms.map((r) => r.roomKey)).size, 30);
  assert.equal(catalog.floors[0].expectedRoomCount, 30);
});

test('a building needs a supported planKind', () => {
  const { catalog, readSvg } = loadCanonical();
  const broken = structuredClone(catalog);
  broken.buildings[0].planKind = 'photograph';
  const { problems } = validate(broken, readSvg);
  assert.ok(
    problems.some((p) => p.includes('unsupported planKind')),
    'an unknown planKind must be rejected',
  );
});

test('a floor without rooms is valid', () => {
  const { catalog, readSvg } = loadCanonical();
  const overview = catalog.floors.find((f) => f.floorKey === 'koethen-campus-overview-level');
  assert.ok(overview, 'the campus overview floor must exist');
  assert.equal(overview.expectedRoomCount, 0);
  assert.equal(catalog.rooms.filter((r) => r.floorKey === overview.floorKey).length, 0);

  const { problems } = validate(catalog, readSvg);
  assert.deepEqual(problems, [], 'a room-less floor must not be an error');
});

test('a room-less floor still rejects stray room elements', () => {
  const { catalog, readSvg } = loadCanonical();
  const patched = structuredClone(catalog);
  const overview = patched.floors.find((f) => f.floorKey === 'koethen-campus-overview-level');
  overview.expectedRoomCount = 1;
  const { problems } = validate(patched, readSvg);
  assert.ok(
    problems.some((p) => p.includes('expected 1 rooms, found 0')),
    'the expected count must still be enforced at zero',
  );
});
