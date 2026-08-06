// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { buildOutputs, generatedFileDrift } from '../src/generate.mjs';
import { findRooms, findUnsafe, parseSvgDocument, walkElements } from '../src/svg-reader.mjs';
import { loadCanonical } from '../src/validate.mjs';

function outputs() {
  const { catalog, documents, problems } = loadCanonical();
  assert.deepEqual(problems, [], problems.join('\n'));
  return { files: buildOutputs(catalog, documents), catalog };
}

const MOBILE_CATALOG = 'apps/mobile/assets/maps/map_catalog.json';
const MOBILE_SVG = 'apps/mobile/assets/maps/demo-north/level2.svg';
const MOBILE_SVG_LEVEL1 = 'apps/mobile/assets/maps/demo-north/level1.svg';
const MOBILE_CAMPUS_SVG = 'apps/mobile/assets/maps/campus/koethen-overview.svg';

test('emits exactly the expected generated files', () => {
  const { files } = outputs();
  assert.deepEqual(
    [...files.keys()].sort(),
    [MOBILE_CATALOG, MOBILE_SVG, MOBILE_SVG_LEVEL1, MOBILE_CAMPUS_SVG].sort(),
  );
});

test('generation is deterministic', () => {
  const a = outputs().files;
  const b = outputs().files;
  for (const [path, content] of a) {
    assert.equal(content, b.get(path), `${path} is not reproducible`);
  }
});

test('the mobile catalogue carries the mapping Flutter needs', () => {
  const { files, catalog } = outputs();
  const mobile = JSON.parse(files.get(MOBILE_CATALOG));

  assert.equal(mobile.mapVersion, catalog.mapVersion);
  assert.equal(mobile.schemaVersion, catalog.schemaVersion);
  assert.equal(mobile.rooms.length, 60);
  assert.equal(mobile.floors.length, 3);
  assert.equal(mobile.buildings.length, 2);

  const room = mobile.rooms.find((r) => r.roomNumber === 'B.201');
  assert.ok(room, 'B.201 must be present');
  assert.equal(room.roomKey, 'demo-north-level2-b201');
  assert.equal(room.floorKey, 'demo-north-level2');
  assert.equal(room.roomType, 'lecture');
  assert.ok(Number.isFinite(room.focus.x) && Number.isFinite(room.focus.y));
  assert.ok(room.bounds.width > 0 && room.bounds.height > 0);

  const demoFloor = mobile.floors.find((f) => f.floorKey === 'demo-north-level2');
  assert.equal(demoFloor.svgAsset, 'assets/maps/demo-north/level2.svg');
  assert.ok(demoFloor.viewBox.width > 0);

  // The two storeys of the demo building share a drawing but never a key: the
  // same shape under two floor keys is exactly how a tap could otherwise land
  // on the room one floor up.
  const first = mobile.rooms.find((r) => r.roomNumber === 'B.101');
  assert.ok(first, 'B.101 must be present');
  assert.equal(first.roomKey, 'demo-north-level1-b101');
  assert.equal(first.floorKey, 'demo-north-level1');
  assert.equal(
    mobile.floors.find((f) => f.floorKey === 'demo-north-level1').svgAsset,
    'assets/maps/demo-north/level1.svg',
  );
});

test('the demo building lists its lower storey first', () => {
  const { files } = outputs();
  const mobile = JSON.parse(files.get(MOBILE_CATALOG));

  // A picker that offers the second floor above the first reads backwards.
  const demo = mobile.floors
    .filter((f) => f.buildingKey === 'demo-north')
    .sort((a, b) => a.sortOrder - b.sortOrder);
  assert.deepEqual(
    demo.map((f) => f.floorKey),
    ['demo-north-level1', 'demo-north-level2'],
  );
});

test('the mobile catalogue carries building and floor names, but no room prose', () => {
  const { files } = outputs();
  const mobile = JSON.parse(files.get(MOBILE_CATALOG));

  // Building and floor names are bundled ON PURPOSE. They name the map's own
  // navigation, and a building without rooms — the campus overview — has no
  // room DTO through which the Campus API could ever deliver them. Bundling
  // both languages keeps the picker translated without a network round-trip.
  for (const building of mobile.buildings) {
    assert.ok(building.nameDe.length > 0, `${building.buildingKey} is missing nameDe`);
    assert.ok(building.nameEn.length > 0, `${building.buildingKey} is missing nameEn`);
  }
  for (const floor of mobile.floors) {
    assert.ok(floor.nameDe.length > 0, `${floor.floorKey} is missing nameDe`);
    assert.ok(floor.nameEn.length > 0, `${floor.floorKey} is missing nameEn`);
  }

  const overview = mobile.buildings.find((b) => b.buildingKey === 'koethen-campus-overview');
  assert.equal(overview.nameDe, 'Campus Köthen – Übersicht');
  assert.equal(overview.nameEn, 'Campus Köthen – Overview');

  // The app shows a different notice per kind of drawing, so the claim travels
  // with the data and a new building cannot inherit the wrong one.
  assert.equal(overview.planKind, 'schematic');
  assert.equal(mobile.buildings.find((b) => b.buildingKey === 'demo-north').planKind, 'fictional');
  const overviewFloor = mobile.floors.find((f) => f.floorKey === 'koethen-campus-overview-level');
  assert.equal(overviewFloor.nameDe, 'Campusübersicht');
  assert.equal(overviewFloor.nameEn, 'Campus overview');

  // Room-level prose stays with the Campus API, which serves it per locale and
  // lets the editorial team change it without an app release.
  for (const room of mobile.rooms) {
    for (const forbidden of ['displayName', 'description', 'nameDe', 'nameEn']) {
      assert.ok(!(forbidden in room), `room ${room.roomKey} must not carry ${forbidden}`);
    }
  }
});

test('a floor without rooms is generated and carries no rooms', () => {
  const { files } = outputs();
  const mobile = JSON.parse(files.get(MOBILE_CATALOG));

  const overviewFloor = mobile.floors.find((f) => f.floorKey === 'koethen-campus-overview-level');
  assert.ok(overviewFloor, 'the campus overview floor must be generated');
  assert.equal(overviewFloor.svgAsset, 'assets/maps/campus/koethen-overview.svg');
  assert.equal(overviewFloor.viewBox.width, 1748);
  assert.equal(overviewFloor.viewBox.height, 900);
  assert.equal(
    mobile.rooms.filter((r) => r.floorKey === 'koethen-campus-overview-level').length,
    0,
  );
  // No invented geometry sneaks in through the second building either.
  assert.equal(mobile.rooms.filter((r) => r.buildingKey === 'koethen-campus-overview').length, 0);
});

test('the campus overview keeps its building groups and drops German labels', () => {
  const { files } = outputs();
  const svg = files.get(MOBILE_CAMPUS_SVG);
  const root = parseSvgDocument(svg);

  const keys = [];
  let uses = 0;
  let defs = 0;
  for (const element of walkElements(root)) {
    if (element.attrs?.['data-building-key']) keys.push(element.attrs['data-building-key']);
    if (element.name === 'use') uses += 1;
    if (element.name === 'defs') defs += 1;
  }
  assert.equal(keys.length, 21, 'all 21 building groups must survive generation');
  assert.equal(new Set(keys).size, 21, 'building keys must stay unique');

  // Local fragment references are kept because flutter_svg renders them; a
  // pixel probe in the Flutter suite is what actually proves that.
  assert.equal(defs, 1);
  assert.ok(uses > 0, '<use> references must survive');

  // Language-neutral building codes stay; German category words do not. The
  // check walks TEXT NODES rather than the raw string: `data-building-number`
  // still carries "Mensa" as metadata, and metadata renders nothing.
  const rendered = [];
  for (const element of walkElements(root)) {
    assert.ok(!['title', 'desc'].includes(element.name), `<${element.name}> must be stripped`);
    if (element.name !== 'text' && element.name !== 'tspan') continue;
    const value = (element.children ?? [])
      .filter((child) => child.type === 'text')
      .map((child) => child.value.trim())
      .join('')
      .trim();
    if (value.length > 0) rendered.push(value);
  }
  assert.ok(rendered.includes('TZK'), 'neutral building codes must survive');
  assert.ok(rendered.includes('Bernburger Straße'), 'street proper nouns must survive');
  for (const german of ['Mensa', 'KITA', 'Richtung City']) {
    assert.ok(!rendered.includes(german), `"${german}" must not be drawn in the asset`);
  }
});

test('the mobile SVG keeps every room element and its geometry', () => {
  const { files } = outputs();
  const root = parseSvgDocument(files.get(MOBILE_SVG));
  const rooms = findRooms(root);
  assert.equal(rooms.length, 30);
  assert.equal(new Set(rooms.map((r) => r.attrs['data-room-key'])).size, 30);
  for (const room of rooms) {
    assert.ok(room.attrs.id.startsWith('room-'));
    assert.ok(Number.isFinite(Number(room.attrs.width)));
  }
});

test('the mobile SVG contains no language-specific text beyond room numbers', () => {
  const { files, catalog } = outputs();
  const root = parseSvgDocument(files.get(MOBILE_SVG));
  const numbers = new Set(catalog.rooms.map((r) => r.roomNumber));

  for (const element of walkElements(root)) {
    if (['title', 'desc'].includes(element.name)) {
      assert.fail(`<${element.name}> carries prose and must be stripped`);
    }
    if (element.name !== 'text' && element.name !== 'tspan') continue;
    const value = (element.children ?? [])
      .filter((child) => child.type === 'text')
      .map((child) => child.value.trim())
      .join('')
      .trim();
    if (value.length === 0) continue;
    assert.ok(
      numbers.has(value),
      `"${value}" is prose; only language-neutral room numbers may remain`,
    );
  }
});

test('the mobile SVG has no dangling references to stripped prose nodes', () => {
  const { files } = outputs();
  const root = parseSvgDocument(files.get(MOBILE_SVG));
  const ids = new Set();
  for (const element of walkElements(root)) {
    if (element.attrs?.id) ids.add(element.attrs.id);
  }
  for (const element of walkElements(root)) {
    for (const attr of ['aria-labelledby', 'aria-describedby']) {
      const value = element.attrs?.[attr];
      if (!value) continue;
      for (const reference of String(value).split(/\s+/).filter(Boolean)) {
        assert.ok(ids.has(reference), `${attr} points at removed node "${reference}"`);
      }
    }
  }
});

test('the mobile SVG carries no construct the Flutter renderer ignores', () => {
  // flutter_svg's compiler reports "unhandled element <style/>" and drops the
  // whole stylesheet, which would leave every room unstyled. Styles are
  // therefore resolved into presentation attributes at generation time, and
  // markers — also unsupported — are removed with their references.
  const { files } = outputs();
  const root = parseSvgDocument(files.get(MOBILE_SVG));

  for (const element of walkElements(root)) {
    assert.notEqual(element.name, 'style', '<style> is not supported by the renderer');
    assert.notEqual(element.name, 'marker', '<marker> is not supported by the renderer');
    for (const attr of Object.keys(element.attrs ?? {})) {
      assert.ok(!attr.startsWith('marker-'), `${attr} references an unsupported marker`);
    }
  }
});

test('every room rectangle carries an explicit fill and stroke', () => {
  const { files } = outputs();
  const root = parseSvgDocument(files.get(MOBILE_SVG));
  for (const room of findRooms(root)) {
    assert.match(
      String(room.attrs.fill ?? ''),
      /^#[0-9a-f]{6}$/i,
      `room ${room.attrs['data-room-key']} must have an inlined fill`,
    );
    assert.ok(room.attrs.stroke, `room ${room.attrs['data-room-key']} must have an inlined stroke`);
  }
});

test('room types keep their distinct inlined colours', () => {
  const { files, catalog } = outputs();
  const root = parseSvgDocument(files.get(MOBILE_SVG));
  const byKey = new Map(catalog.rooms.map((r) => [r.roomKey, r]));

  const fillByType = new Map();
  for (const element of findRooms(root)) {
    const type = byKey.get(element.attrs['data-room-key']).roomType;
    fillByType.set(type, element.attrs.fill);
  }

  // lecture and office are visibly different in the canonical stylesheet; if
  // the cascade were applied wrongly they would collapse onto one colour.
  assert.equal(fillByType.get('lecture'), '#f8e3bf');
  assert.equal(fillByType.get('office'), '#ebe8f2');
  assert.notEqual(fillByType.get('lecture'), fillByType.get('office'));
});

test('the mobile SVG is safe and self-contained', () => {
  const { files } = outputs();
  const svg = files.get(MOBILE_SVG);
  assert.deepEqual(findUnsafe(parseSvgDocument(svg)), []);
  assert.ok(!/https?:\/\//.test(svg.replace(/xmlns="[^"]*"/g, '')));
});

test('an invalid catalogue produces no files at all', () => {
  const { catalog, documents } = loadCanonical();
  const broken = structuredClone(catalog);
  broken.rooms[0].roomKey = 'not-in-any-svg';
  assert.throws(() => buildOutputs(broken, documents), /roomKey|SVG element/i);
});

// --- drift ------------------------------------------------------------------

test('drift check passes for the committed generated assets', () => {
  const drift = generatedFileDrift();
  assert.deepEqual(drift, [], `generated assets are stale:\n${drift.join('\n')}`);
});

test('drift check reports a tampered generated asset', () => {
  const drift = generatedFileDrift({
    readFile: (path) => (path.endsWith('.svg') ? '<svg/>' : undefined),
  });
  assert.ok(drift.length > 0);
});
