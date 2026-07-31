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

test('emits exactly the expected generated files', () => {
  const { files } = outputs();
  assert.deepEqual([...files.keys()].sort(), [MOBILE_CATALOG, MOBILE_SVG].sort());
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
  assert.equal(mobile.rooms.length, 30);
  assert.equal(mobile.floors.length, 1);
  assert.equal(mobile.buildings.length, 1);

  const room = mobile.rooms.find((r) => r.roomNumber === 'B.201');
  assert.ok(room, 'B.201 must be present');
  assert.equal(room.roomKey, 'demo-north-level2-b201');
  assert.equal(room.floorKey, 'demo-north-level2');
  assert.equal(room.roomType, 'lecture');
  assert.ok(Number.isFinite(room.focus.x) && Number.isFinite(room.focus.y));
  assert.ok(room.bounds.width > 0 && room.bounds.height > 0);

  assert.equal(mobile.floors[0].svgAsset, 'assets/maps/demo-north/level2.svg');
  assert.ok(mobile.floors[0].viewBox.width > 0);
});

test('the mobile catalogue carries no localised prose', () => {
  const { files } = outputs();
  const serialised = files.get(MOBILE_CATALOG);
  // Names are served by the Campus API per locale; bundling German strings
  // here would bypass the DE/EN contract.
  for (const forbidden of ['nameDe', 'nameEn', 'Obergeschoss', 'Demogebäude']) {
    assert.ok(!serialised.includes(forbidden), `generated catalogue must not contain ${forbidden}`);
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
