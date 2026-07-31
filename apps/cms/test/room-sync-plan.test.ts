// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  applyPlan,
  planRoomSync,
  type CatalogRoom,
  type ExistingRoom,
  type RoomWriter,
} from '../src/catalog/room-sync-plan';

function catalogRoom(overrides: Partial<CatalogRoom> = {}): CatalogRoom {
  return {
    roomKey: 'demo-north-level2-b201',
    editorLabel: 'B.201 · Demogebäude Nord (fiktiv)',
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
    ...overrides,
  };
}

function existingRoom(overrides: Partial<ExistingRoom> = {}): ExistingRoom {
  return {
    documentId: 'doc-1',
    catalogActive: true,
    ...catalogRoom(),
    ...overrides,
  };
}

/** Records everything a writer was asked to do, without any database. */
function recordingWriter() {
  const calls: Array<{ op: string; roomKey: string; data?: Record<string, unknown> }> = [];
  const writer: RoomWriter = {
    create: async (data) => {
      calls.push({ op: 'create', roomKey: String(data.roomKey), data });
    },
    update: async (documentId, data) => {
      calls.push({ op: 'update', roomKey: String(data.roomKey ?? documentId), data });
    },
    deactivate: async (documentId, roomKey) => {
      calls.push({ op: 'deactivate', roomKey });
    },
  };
  return { writer, calls };
}

test('a room that does not exist yet is created', () => {
  const plan = planRoomSync([catalogRoom()], []);
  assert.equal(plan.summary.create, 1);
  assert.equal(plan.summary.update, 0);
  assert.equal(plan.entries[0].kind, 'create');
});

test('a room whose catalogue fields changed is updated', () => {
  const plan = planRoomSync(
    [catalogRoom({ roomType: 'seminar', sortOrder: 20 })],
    [existingRoom()],
  );
  assert.equal(plan.summary.update, 1);
  const entry = plan.entries[0];
  assert.equal(entry.kind, 'update');
  if (entry.kind !== 'update') return;
  assert.deepEqual(entry.changedFields.sort(), ['roomType', 'sortOrder']);
});

test('an identical room is left untouched', () => {
  const plan = planRoomSync([catalogRoom()], [existingRoom()]);
  assert.equal(plan.summary.unchanged, 1);
  assert.equal(plan.summary.update, 0);
});

test('a room missing from the catalogue is deactivated, never deleted', () => {
  const plan = planRoomSync([], [existingRoom()]);
  assert.equal(plan.summary.deactivate, 1);
  assert.equal(plan.entries[0].kind, 'deactivate');
  assert.ok(!JSON.stringify(plan.entries).includes('delete'));
});

test('an already deactivated missing room stays unchanged', () => {
  const plan = planRoomSync([], [existingRoom({ catalogActive: false })]);
  assert.equal(plan.summary.unchanged, 1);
  assert.equal(plan.summary.deactivate, 0);
});

test('a room that reappears is reactivated', () => {
  const plan = planRoomSync([catalogRoom()], [existingRoom({ catalogActive: false })]);
  assert.equal(plan.summary.update, 1);
  const entry = plan.entries[0];
  assert.equal(entry.kind, 'update');
  if (entry.kind !== 'update') return;
  assert.ok(entry.changedFields.includes('catalogActive'));
  assert.equal(entry.data.catalogActive, true);
});

test('the plan never carries editorial fields or relations', () => {
  const plan = planRoomSync([catalogRoom({ roomType: 'office' })], [existingRoom()]);
  const serialised = JSON.stringify(plan);
  for (const field of [
    'displayNameDe',
    'displayNameEn',
    'descriptionDe',
    'descriptionEn',
    'isVisible',
    'contactPersons',
    'contactAreas',
  ]) {
    assert.ok(!serialised.includes(field), `${field} must never appear in a sync plan`);
  }
});

test('editorial values on the existing row are not compared or overwritten', () => {
  const existing = {
    ...existingRoom(),
    displayNameDe: 'Redaktionell gepflegt',
    isVisible: false,
    contactPersons: [{ id: 1 }],
  } as ExistingRoom;
  const plan = planRoomSync([catalogRoom()], [existing]);
  assert.equal(plan.summary.unchanged, 1, 'editorial content must not trigger an update');
});

test('the plan is deterministic and ordered by roomKey', () => {
  const rooms = [
    catalogRoom({ roomKey: 'b-2', sortOrder: 20 }),
    catalogRoom({ roomKey: 'a-1', sortOrder: 10 }),
  ];
  const keys = planRoomSync(rooms, []).entries.map((e) => e.roomKey);
  assert.deepEqual(keys, ['a-1', 'b-2']);
});

// --- application ------------------------------------------------------------

test('a dry run writes nothing at all', async () => {
  const { writer, calls } = recordingWriter();
  const plan = planRoomSync([catalogRoom(), catalogRoom({ roomKey: 'x-1' })], [existingRoom()]);
  await applyPlan(plan, writer, { dryRun: true });
  assert.deepEqual(calls, []);
});

test('applying a plan performs exactly the planned writes', async () => {
  const { writer, calls } = recordingWriter();
  const plan = planRoomSync(
    [catalogRoom({ roomKey: 'new-1' })],
    [existingRoom({ roomKey: 'gone-1', documentId: 'doc-gone' })],
  );
  await applyPlan(plan, writer, { dryRun: false });

  assert.deepEqual(calls.map((c) => c.op).sort(), ['create', 'deactivate']);
});

test('running the sync twice produces no further writes', async () => {
  const catalog = [catalogRoom()];
  const first = planRoomSync(catalog, []);
  assert.equal(first.summary.create, 1);

  // Simulate the created row coming back from the CMS.
  const persisted: ExistingRoom = { documentId: 'doc-new', catalogActive: true, ...catalogRoom() };
  const second = planRoomSync(catalog, [persisted]);

  const { writer, calls } = recordingWriter();
  await applyPlan(second, writer, { dryRun: false });
  assert.deepEqual(calls, [], 'a second run must be a no-op');
  assert.equal(second.summary.unchanged, 1);
});

test('a duplicated roomKey in the catalogue is rejected before any write', () => {
  assert.throws(() => planRoomSync([catalogRoom(), catalogRoom()], []), /duplicate/i);
});
