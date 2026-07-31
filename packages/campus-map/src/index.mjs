// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/** Public surface of the map package. */

export {
  buildFromCanonical,
  buildMobileCatalog,
  buildMobileSvg,
  buildOutputs,
  generatedFileDrift,
  writeGenerated,
} from './generate.mjs';

export { CATALOG_PATH, PACKAGE_ROOT, ROOM_TYPES, loadCanonical, validate } from './validate.mjs';

export { SvgParseError, findRooms, findUnsafe, parseSvgDocument } from './svg-reader.mjs';

/**
 * Joins rooms with their floor and building so a consumer gets one flat,
 * self-describing record per room. This is the shape the CMS room collection
 * mirrors, so the join lives here rather than being repeated per consumer.
 */
export function toFlatRooms(catalog) {
  const buildings = new Map(catalog.buildings.map((b) => [b.buildingKey, b]));
  const floors = new Map(catalog.floors.map((f) => [f.floorKey, f]));

  return catalog.rooms
    .map((room) => {
      const building = buildings.get(room.buildingKey);
      const floor = floors.get(room.floorKey);
      if (!building || !floor) {
        throw new Error(`room "${room.roomKey}" references an unknown building or floor`);
      }
      return {
        roomKey: room.roomKey,
        editorLabel: `${room.roomNumber} · ${building.nameDe}`,
        roomNumber: room.roomNumber,
        buildingKey: building.buildingKey,
        buildingNameDe: building.nameDe,
        buildingNameEn: building.nameEn,
        floorKey: floor.floorKey,
        floorLevel: floor.level,
        floorNameDe: floor.nameDe,
        floorNameEn: floor.nameEn,
        roomType: room.roomType,
        mapVersion: catalog.mapVersion,
        sortOrder: room.sortOrder,
      };
    })
    .sort((a, b) => a.sortOrder - b.sortOrder || a.roomKey.localeCompare(b.roomKey));
}
