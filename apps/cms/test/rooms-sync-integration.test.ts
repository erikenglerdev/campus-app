// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/**
 * Checks how the CMS sync consumes the real map catalogue — still without any
 * database: only the pure planner and the catalogue package are involved.
 */

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { CATALOG_MANAGED_FIELDS } from '../src/catalog/room-guard';
import { applyPlan, planRoomSync, type ExistingRoom } from '../src/catalog/room-sync-plan';
import { parseSyncArgs } from '../src/catalog/sync-args';

async function catalogRooms() {
  const map = await import('@campus/map');
  const { catalog, problems } = map.loadCanonical();
  assert.deepEqual(problems, [], problems.join('\n'));
  return map.toFlatRooms(catalog);
}

test('the committed catalogue yields exactly 60 syncable demo rooms', async () => {
  const rooms = await catalogRooms();
  // Two storeys of 30. Counting the distinct keys as well is the point: both
  // floors were drawn from the same file, so a missed rename would surface
  // here as a collision rather than as a room that exists twice in the CMS.
  assert.equal(rooms.length, 60);
  assert.equal(new Set(rooms.map((r) => r.roomKey)).size, 60);
  assert.ok(rooms.every((r) => r.buildingKey === 'demo-north'));
  for (const floorKey of ['demo-north-level1', 'demo-north-level2']) {
    assert.equal(rooms.filter((r) => r.floorKey === floorKey).length, 30);
  }
});

test('every catalogue-managed CMS field is supplied by the catalogue', async () => {
  const [room] = await catalogRooms();
  for (const field of CATALOG_MANAGED_FIELDS) {
    if (field === 'catalogActive') continue; // derived by the planner
    assert.ok(field in room, `the catalogue must supply ${field}`);
  }
});

test('a first sync would create exactly 60 rooms', async () => {
  const plan = planRoomSync(await catalogRooms(), []);
  assert.equal(plan.summary.create, 60);
  assert.equal(plan.summary.update, 0);
  assert.equal(plan.summary.deactivate, 0);
});

test('a second sync against the persisted result is a no-op', async () => {
  const rooms = await catalogRooms();
  const persisted: ExistingRoom[] = rooms.map((room, index) => ({
    documentId: `doc-${index}`,
    catalogActive: true,
    ...room,
  }));

  const plan = planRoomSync(rooms, persisted);
  assert.equal(plan.summary.unchanged, 60);
  assert.equal(plan.summary.create + plan.summary.update + plan.summary.deactivate, 0);

  const calls: string[] = [];
  await applyPlan(
    plan,
    {
      create: async () => void calls.push('create'),
      update: async () => void calls.push('update'),
      deactivate: async () => void calls.push('deactivate'),
    },
    { dryRun: false },
  );
  assert.deepEqual(calls, []);
});

test('editorial work on a persisted room survives a resync', async () => {
  const rooms = await catalogRooms();
  const persisted: ExistingRoom[] = rooms.map((room, index) => ({
    documentId: `doc-${index}`,
    catalogActive: true,
    ...room,
    displayNameDe: 'Redaktioneller Name',
    descriptionEn: 'Editorial description',
    isVisible: false,
    contactPersons: [{ id: 7 }],
    contactAreas: [{ id: 9 }],
  }));

  const plan = planRoomSync(rooms, persisted);
  assert.equal(plan.summary.unchanged, 60);
  const serialised = JSON.stringify(plan);
  assert.ok(!serialised.includes('Redaktioneller Name'));
  assert.ok(!serialised.includes('contactPersons'));
});

// --- CLI arguments ----------------------------------------------------------

test("--dry-run is recognised, including behind pnpm's separator", () => {
  assert.deepEqual(parseSyncArgs(['node', 'x', '--dry-run']), { dryRun: true });
  assert.deepEqual(parseSyncArgs(['node', 'x', '--', '--dry-run']), { dryRun: true });
  assert.deepEqual(parseSyncArgs(['node', 'x']), { dryRun: false });
  assert.deepEqual(parseSyncArgs(['node', 'x', '--']), { dryRun: false });
});

test('an unknown option is rejected rather than ignored', () => {
  assert.throws(() => parseSyncArgs(['node', 'x', '--force']), /Unknown option/);
});
